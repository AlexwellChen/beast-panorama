import AppKit
let output=CommandLine.arguments[1]
let image=NSImage(size:NSSize(width:1024,height:1024))
image.lockFocus()
let background=NSBezierPath(roundedRect:NSRect(x:48,y:48,width:928,height:928),xRadius:206,yRadius:206)
NSColor(calibratedRed:0.045,green:0.105,blue:0.16,alpha:1).setFill(); background.fill()
let glow=NSGradient(starting:NSColor(calibratedRed:0.08,green:0.29,blue:0.39,alpha:1),ending:NSColor(calibratedRed:0.025,green:0.06,blue:0.12,alpha:1))!
glow.draw(in:background,angle:70)
let globe=NSBezierPath(ovalIn:NSRect(x:215,y:215,width:594,height:594)); globe.lineWidth=14
NSColor(calibratedRed:0.39,green:0.88,blue:0.87,alpha:0.75).setStroke(); globe.stroke()
for rect in [NSRect(x:332,y:215,width:360,height:594),NSRect(x:215,y:375,width:594,height:274)] {
 let path=NSBezierPath(ovalIn:rect); path.lineWidth=9; NSColor.white.withAlphaComponent(0.22).setStroke(); path.stroke()
}
let lens=NSBezierPath(roundedRect:NSRect(x:167,y:369,width:690,height:286),xRadius:98,yRadius:98)
NSColor(calibratedRed:0.05,green:0.12,blue:0.18,alpha:1).setFill(); lens.fill()
lens.lineWidth=18; NSColor(calibratedRed:0.56,green:0.96,blue:0.93,alpha:1).setStroke(); lens.stroke()
let play=NSBezierPath(); play.move(to:NSPoint(x:455,y:425)); play.line(to:NSPoint(x:592,y:512)); play.line(to:NSPoint(x:455,y:599)); play.close(); NSColor.white.setFill(); play.fill()
image.unlockFocus()
let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))
