import Cocoa
import Metal
import MetalKit

// ============================================================
// MARK: - Metal 流光视图
// ============================================================
/// 用片元着色器在屏幕四边绘制流光：一条沿周长固定分布的色带 +
/// 一个沿周长移动的亮度遮罩，外加三层不同半径的辉光衰减。
final class MetalGlowView: MTKView, MTKViewDelegate {

    private struct Uniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var duration: Float
        var width: Float
        var brightness: Float
        var clockwise: Float
        var mode: Float
        var pulse: Float
        var alpha: Float
        var colorCount: Float
    }

    private static let shaderSource = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex VertexOut vertex_main(uint vid [[vertex_id]]) {
        float2 positions[4] = {
            float2(-1.0, -1.0), float2( 1.0, -1.0),
            float2(-1.0,  1.0), float2( 1.0,  1.0)
        };
        float2 uvs[4] = {
            float2(0.0, 1.0), float2(1.0, 1.0),
            float2(0.0, 0.0), float2(1.0, 0.0)
        };
        VertexOut out;
        out.position = float4(positions[vid], 0.0, 1.0);
        out.uv = uvs[vid];
        return out;
    }

    struct Uniforms {
        float2 resolution;
        float time;
        float duration;
        float width;
        float brightness;
        float clockwise;
        float mode;
        float pulse;
        float alpha;
        float colorCount;
    };

    float3 palette(float x, constant float4 *colors, int count) {
        if (count <= 0) return float3(0.65, 0.20, 0.95);
        x = fract(x);
        float scaled = x * float(count);
        int i = int(floor(scaled));
        float f = fract(scaled);
        int j = i + 1;
        if (j >= count) j = 0;
        return mix(colors[i].rgb, colors[j].rgb, smoothstep(0.0, 1.0, f));
    }

    fragment float4 fragment_main(VertexOut in [[stage_in]],
                                  constant Uniforms &u [[buffer(0)]],
                                  constant float4 *colors [[buffer(1)]]) {
        float2 res = max(u.resolution, float2(1.0));
        float2 inv = float2(1.0) / res;
        float2 p = in.uv * res;

        float dt = p.y;
        float db = res.y - p.y;
        float dl = p.x;
        float dr = res.x - p.x;
        float edgeDist = min(min(dt, db), min(dl, dr));

        float t;
        if (dt <= dl && dt <= dr && dt <= db) {
            t = p.x * inv.x * 0.25;
        } else if (dr <= dl && dr <= db) {
            t = 0.25 + p.y * inv.y * 0.25;
        } else if (db <= dl && db <= dr) {
            t = 0.5 + (1.0 - p.x * inv.x) * 0.25;
        } else {
            t = 0.75 + (1.0 - p.y * inv.y) * 0.25;
        }
        if (u.clockwise < 0.5) t = 1.0 - t;

        float3 col = palette(t, colors, int(u.colorCount));

        float flow = u.time / max(u.duration, 0.001);
        float band = 1.0;
        if (u.mode < 0.5) {
            float seg = fract(t * 4.0 - flow);
            band = smoothstep(0.0, 0.04, seg) * (1.0 - smoothstep(0.28, 0.36, seg));
        } else {
            float breath = 0.5 + 0.5 * sin(6.2831853 * u.time / max(u.duration * 0.7, 0.001));
            band = 0.35 + 0.65 * breath;
        }

        float w = max(u.width, 1.0);
        float core  = exp(-pow(edgeDist / (w * 0.35 + 0.5), 2.0));
        float mid   = exp(-pow(edgeDist / (w * 1.20 + 1.0), 2.0)) * 0.42;
        float outer = exp(-pow(edgeDist / (w * 3.00 + 2.0), 2.0)) * 0.16;
        float amount = (core + mid + outer) * band * u.brightness * u.alpha;

        float p2 = clamp(u.pulse, 0.0, 1.0);
        col = mix(col, float3(1.0), p2 * 0.85);
        amount *= (1.0 + p2 * 1.5);
        amount = clamp(amount, 0.0, 1.0);

        return float4(col * amount, amount);
    }
    """#

    private var commandQueue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    private var uniformBuffer: MTLBuffer?
    private var colorBuffer: MTLBuffer?
    private var settings: AppSettings?

    private let epoch = ProcessInfo.processInfo.systemUptime
    private let fadeDuration: TimeInterval = 1.5
    private var targetAlpha: Float = 0
    private var currentAlpha: Float = 0
    private var fadeFrom: Float = 0
    private var fadeStart: TimeInterval = 0
    private var pulseStart: TimeInterval = -100

    var isFullyVisible: Bool { targetAlpha > 0.5 && currentAlpha > 0.99 }

    override init(frame frameRect: NSRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        setup()
    }

    convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, device: MTLCreateSystemDefaultDevice())
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        guard let device = device else {
            log("⚠️ Metal 不可用，渲染器保持空实现")
            return
        }

        wantsLayer = true
        clipsToBounds = true
        layer?.isOpaque = false
        (layer as? CAMetalLayer)?.isOpaque = false
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        preferredFramesPerSecond = 60
        autoResizeDrawable = true
        framebufferOnly = true
        isPaused = true

        commandQueue = device.makeCommandQueue()
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size,
                                          options: .storageModeShared)
        colorBuffer = device.makeBuffer(length: 16 * MemoryLayout<SIMD4<Float>>.stride,
                                        options: .storageModeShared)
        buildPipeline(with: device)
        delegate = self
    }

    private func buildPipeline(with device: MTLDevice) {
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        } catch {
            log("❌ Metal shader 编译失败: \(error)")
            return
        }

        guard let vertex = library.makeFunction(name: "vertex_main"),
              let fragment = library.makeFunction(name: "fragment_main") else {
            log("❌ Metal shader 函数缺失")
            return
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment

        guard let attachment = descriptor.colorAttachments[0] else {
            log("❌ Metal 渲染管线缺少颜色附件")
            return
        }
        attachment.pixelFormat = colorPixelFormat
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            log("✅ Metal 流光渲染器就绪")
        } catch {
            log("❌ Metal 渲染管线创建失败: \(error)")
        }
    }

    func update(settings: AppSettings) {
        self.settings = settings
        guard let colorBuffer = colorBuffer else { return }

        var colors = [SIMD4<Float>](repeating: SIMD4<Float>(0, 0, 0, 0), count: 16)
        for (index, item) in settings.currentTheme.colors.prefix(16).enumerated() {
            colors[index] = SIMD4<Float>(Float(item.r), Float(item.g),
                                         Float(item.b), Float(item.a))
        }
        colorBuffer.contents().copyMemory(from: colors,
                                          byteCount: colors.count * MemoryLayout<SIMD4<Float>>.stride)
    }

    func setVisible(_ visible: Bool, animated: Bool) {
        let next: Float = visible ? 1 : 0
        if animated {
            fadeFrom = currentAlpha
            fadeStart = ProcessInfo.processInfo.systemUptime
        } else {
            currentAlpha = next
            fadeFrom = next
        }
        targetAlpha = next
        isPaused = false
    }

    func pulse() {
        setVisible(true, animated: false)
        pulseStart = ProcessInfo.processInfo.systemUptime
    }

    func shutdown() {
        isPaused = true
        delegate = nil
    }

    // MARK: - MTKViewDelegate

    @objc func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    @objc func draw(in view: MTKView) {
        guard let settings = settings,
              let pipeline = pipeline,
              let commandQueue = commandQueue,
              let uniformBuffer = uniformBuffer,
              let colorBuffer = colorBuffer else { return }

        let now = ProcessInfo.processInfo.systemUptime

        if abs(currentAlpha - targetAlpha) > 0.001 {
            let progress = Float(min(max((now - fadeStart) / fadeDuration, 0), 1))
            currentAlpha = fadeFrom + (targetAlpha - fadeFrom) * progress
        } else {
            currentAlpha = targetAlpha
        }

        let elapsed = now - pulseStart
        let pulse: Float = (elapsed >= 0 && elapsed < 0.52)
            ? Float(1.0 - elapsed / 0.52) : 0

        var uniforms = Uniforms(
            resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height)),
            time: Float(now - epoch),
            duration: Float(settings.animationDuration),
            width: Float(settings.baseLineWidth),
            brightness: Float(settings.brightness),
            clockwise: settings.clockwise ? 1 : 0,
            mode: settings.glowMode == .flow ? 0 : 1,
            pulse: pulse,
            alpha: currentAlpha,
            colorCount: Float(min(settings.currentTheme.colors.count, 16))
        )
        uniformBuffer.contents().copyMemory(from: &uniforms,
                                            byteCount: MemoryLayout<Uniforms>.size)

        guard let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor else { return }

        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(colorBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        if currentAlpha <= 0.001 && targetAlpha == 0 && pulse == 0 {
            isPaused = true
        }
    }
}
