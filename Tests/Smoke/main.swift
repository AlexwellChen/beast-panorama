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
let sdk=GlassesSDK()
do { try sdk.connect(url:URL(fileURLWithPath:"/nonexistent/libglasses.dylib")); fatalError("Missing library accepted") } catch { precondition(!sdk.connected) }
print("PASS: axis mapping, recenter, invalid sample, missing SDK")
