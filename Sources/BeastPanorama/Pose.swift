import Foundation
import simd

func mappedPose(_ q: simd_quatf) -> simd_quatf {
    // Beast v2.4.0 observed callback basis: yaw +Y, pitch X, roll Z.
    // The generic header's NWU description does not match this device output.
    return simd_normalize(q)
}
final class PoseStore {
    static let shared = PoseStore()
    private let lock = NSLock()
    private var pose = simd_quatf(angle: 0, axis: SIMD3(0,1,0))
    private var received = 0.0
    private var count = 0
    func put(_ data: UnsafeMutablePointer<Float>?) {
        guard let d = data else { return }
        let v = SIMD4(d[4],d[5],d[6],d[3])
        guard v.x.isFinite, v.y.isFinite, v.z.isFinite, v.w.isFinite, simd_length(v) > 0.1 else { return }
        lock.lock(); defer { lock.unlock() }
        pose = mappedPose(simd_quatf(vector: simd_normalize(v)))
        received = ProcessInfo.processInfo.systemUptime
        count += 1
        if CommandLine.arguments.contains("--diagnostics") && count % 15 == 0 {
            print(String(format: "[POSE-PROBE] t=%.3f euler=%.5f,%.5f,%.5f rawQ=%.6f,%.6f,%.6f,%.6f", received, d[0], d[1], d[2], d[3], d[4], d[5], d[6]))
            fflush(stdout)
        }
    }
    func reset() { lock.lock(); received = 0; count = 0; lock.unlock() }
    func read() -> (simd_quatf, Double, Int) {
        lock.lock(); defer { lock.unlock() }
        return (pose, received, count)
    }
}
