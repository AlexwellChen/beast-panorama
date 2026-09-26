import Foundation
import simd
let q=mappedPose(simd_quatf(angle:.pi/2,axis:SIMD3(0,1,0)))
let ray=q.act(SIMD3<Float>(0,0,-1))
precondition(abs(ray.x+1)<0.0001 && abs(ray.y)<0.0001, "Left turn must look left")
let up=mappedPose(simd_quatf(angle:.pi/4,axis:SIMD3(1,0,0))).act(SIMD3<Float>(0,0,-1))
precondition(up.y > 0.7 && abs(up.x) < 0.0001, "Pitch must look up without yaw")
let roll=mappedPose(simd_quatf(angle:.pi/4,axis:SIMD3(0,0,1)))
precondition(simd_length(roll.act(SIMD3<Float>(0,0,-1))-SIMD3<Float>(0,0,-1)) < 0.0001, "Roll must preserve forward ray")
let rotation=mappedPose(simd_quatf(angle:0.9,axis:simd_normalize(SIMD3(1,2,3))))
precondition(simd_length((rotation.inverse*rotation).imag)<0.0001, "Recenter must cancel orientation")
let store=PoseStore()
var good:[Float]=[0,0,0,1,0,0,0]
good.withUnsafeMutableBufferPointer { store.put($0.baseAddress) }
var bad:[Float]=[0,0,0,.nan,0,0,0]
bad.withUnsafeMutableBufferPointer { store.put($0.baseAddress) }
precondition(store.read().2==1, "Invalid quaternion must be ignored")
// Recorded Beast left-turn callback: dominant +Y rotation, not NWU +Z.
var captured:[Float]=[1.38270,-0.71895,10.73380,0.996703,0.005124,0.093711,-0.012615]
captured.withUnsafeMutableBufferPointer { store.put($0.baseAddress) }
let capturedRay=store.read().0.act(SIMD3<Float>(0,0,-1))
precondition(capturedRay.x < -0.18 && abs(capturedRay.y) < 0.03, "Recorded left turn must stay horizontal")
let held=store.read().0
for _ in 0..<300 { captured.withUnsafeMutableBufferPointer { store.put($0.baseAddress) } }
precondition(abs(simd_dot(held.vector,store.read().0.vector)) > 0.99999, "Held pose must not recenter")
// Drag offsets must remain active while tracking, including non-commuting pitch/yaw.
let forward = SIMD3<Float>(0,0,-1)
let headTurn = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(0,1,0))
let combined = viewingRotation(yaw: 0, pitch: .pi/4, head: headTurn).act(forward)
precondition(simd_length(combined - SIMD3<Float>(-sqrt(0.5),sqrt(0.5),0)) < 0.0001,
             "Vertical drag after a 90-degree head turn must tilt the view up, not roll it")
let offsetRay = viewingRotation(yaw: .pi/4, pitch: 0, head: headTurn).act(forward)
precondition(offsetRay.x < -0.7 && offsetRay.z > 0.7,
             "Mouse yaw must be added to the tracked heading")
for heading: Float in [-2.8, -1.57, -0.6, 0, 0.8, 1.57, 2.8] {
    let pose = simd_quatf(angle: heading, axis: SIMD3<Float>(0,1,0))
        * simd_quatf(angle: 0.3, axis: SIMD3<Float>(1,0,0))
        * simd_quatf(angle: -0.2, axis: SIMD3<Float>(0,0,1))
    let before = viewingRotation(yaw: 0.4, pitch: 0, head: pose)
    let after = viewingRotation(yaw: 0.4, pitch: 0.25, head: pose)
    let localDelta = before.inverse * after
    precondition(abs(localDelta.imag.y) < 0.0001 && abs(localDelta.imag.z) < 0.0001,
                 "Vertical drag must not introduce local yaw or roll at any tracked heading")
    precondition(simd_dot(after.act(forward), before.act(SIMD3<Float>(0,1,0))) > 0.2,
                 "Vertical drag must move toward the current camera's up direction")
}
let mouseOnly = viewingRotation(yaw: 0, pitch: .pi/4).act(forward)
precondition(mouseOnly.y > 0.7, "Mouse-only pitch must remain available")
let centered = viewingRotation(yaw: 0, pitch: 0, head: rotation.inverse * rotation).act(forward)
precondition(simd_length(centered - forward) < 0.0001,
             "Recenter must clear both manual offset and head reference")
let sdk=GlassesSDK()
do { try sdk.connect(url:URL(fileURLWithPath:"/nonexistent/libglasses.dylib")); fatalError("Missing library accepted") } catch { precondition(!sdk.connected) }
print("PASS: axis mapping, mouse + head composition, recenter, invalid sample, missing SDK")
