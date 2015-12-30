//
//   PhyDebug.swift created on 30/12/15
//   Swen project 
//   
//   Copyright 2015 Ashley Towns <code@ashleytowns.id.au>
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

/*
  Here be dragons.

  these classes are used to debug the physics engine to draw Shapes, Constraints and collisions on screen
  since the engine itself uses C callbacks we have to trampoline out (passing the class instance in
  as a pointer that the engine threads through to call backs, the closures trampoline them out to
  the delegate class.

  It works!
*/

import CSDL
import CChipmunk

public struct DebugDrawFlags : OptionSetType {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  static let Shapes           = DebugDrawFlags(rawValue: CP_SPACE_DEBUG_DRAW_SHAPES.rawValue)
  static let Constraints      = DebugDrawFlags(rawValue: CP_SPACE_DEBUG_DRAW_CONSTRAINTS.rawValue)
  static let CollisionPoints  = DebugDrawFlags(rawValue: CP_SPACE_DEBUG_DRAW_COLLISION_POINTS.rawValue)
}

// gets handed the nice swiftized primitives
public protocol PhyDebugDrawDelegate {
  func drawCircle(pos pos: Vector<Double>,
                  angle: Double,
                  radius: Double,
                  outlineColor: Colour,
                  fillColor: Colour)

  func drawSegment(a a: Vector<Double>,
                   b: Vector<Double>,
                   color: Colour)

  func drawFatSegment(a a: Vector<Double>,
                      b: Vector<Double>,
                      radius: Double,
                      outlineColor: Colour,
                      fillColor: Colour)

  func drawPolygon(count count: Int32,
                   // verts: UnsafePointer<cpVect>, -- ugh not dealing with this right now
                   radius: Double,
                   outlineColor: Colour,
                   fillColor: Colour)

  func drawDot(size size: Double,
               pos: Vector<Double>,
               color: Colour)

  func drawColour(shape shape: COpaquePointer) -> Colour
}

// Why not generics? Closures can't capture generic classes.
public final class PhyDebug: AnyObject {
  let delegate: PhyDebugDrawDelegate

  public init(delegate: PhyDebugDrawDelegate) {
    self.delegate = delegate
  }

  public func generateStruct() -> cpSpaceDebugDrawOptions {
    var debugOpts = cpSpaceDebugDrawOptions()

    /* Trampolines from c back into swift world */
    let drawSegment: cpSpaceDebugDrawSegmentImpl = {
      (a: cpVect,
       b: cpVect,
       color: cpSpaceDebugColor,
       data: cpDataPointer) -> Void in

      let r: PhyDebug = Unmanaged<PhyDebug>.fromOpaque(COpaquePointer(data)).takeUnretainedValue()
      r.drawSegmentTrampoline(a: a, b: b, color: color)
    }

    let drawCircle: cpSpaceDebugDrawCircleImpl = {
      (pos: cpVect,
       angle: Double,
       radius: Double,
       outlineColor: cpSpaceDebugColor,
       fillColor: cpSpaceDebugColor,
       data: cpDataPointer) in

      // let r: PhyDebug = Unmanaged<PhyDebug>.fromOpaque(COpaquePointer(data)).takeUnretainedValue()
      // r.drawCircleTrampoline(pos: pos, angle: angle, radius: radius, outlineColor: outlineColor, fillColor: fillColor)
      let klass = unsafeBitCast(data, PhyDebug.self)
      klass.drawCircleTrampoline(pos: pos, angle: angle, radius: radius, outlineColor: outlineColor, fillColor: fillColor)
    }

    let drawPolygon: cpSpaceDebugDrawPolygonImpl = {
      (count: Int32,
       verts: UnsafePointer<cpVect>,
       radius: Double,
       outlineColor: cpSpaceDebugColor,
       fillColor: cpSpaceDebugColor,
       data: cpDataPointer) in

//      let r: PhyDebug = Unmanaged<PhyDebug>.fromOpaque(COpaquePointer(data)).takeUnretainedValue()
//      r.drawPolygonTrampoline(count: count, verts: verts, radius: radius, outlineColor: outlineColor,
//          fillColor: fillColor)
      let klass = unsafeBitCast(data, PhyDebug.self)
      klass.drawPolygonTrampoline(count: count, verts: verts, radius: radius, outlineColor: outlineColor,
          fillColor: fillColor)
    }

    let drawFatSegment: cpSpaceDebugDrawFatSegmentImpl = {
      (a: cpVect,
       b: cpVect,
       radius: Double,
       outlineColor: cpSpaceDebugColor,
       fillColor: cpSpaceDebugColor,
       data: cpDataPointer) in

      let r: PhyDebug = Unmanaged<PhyDebug>.fromOpaque(COpaquePointer(data)).takeUnretainedValue()
      r.drawFatSegmentTrampoline(a: a, b: b, radius: radius, outlineColor: outlineColor, fillColor: fillColor)
    }

    let drawDot: cpSpaceDebugDrawDotImpl = {
      (size: Double,
       pos: cpVect,
       color: cpSpaceDebugColor,
       data: cpDataPointer) in

      let r: PhyDebug = Unmanaged<PhyDebug>.fromOpaque(COpaquePointer(data)).takeUnretainedValue()
      r.drawDotTrampoline(size: size, pos: pos, color: color)
    }

    let drawColour: cpSpaceDebugDrawColorForShapeImpl = {
      (shape: COpaquePointer,
       data: cpDataPointer) in
      let klass = unsafeBitCast(data, PhyDebug.self)
      let colour = klass.drawColourTrampoline(shape)
      return colour
    }

    debugOpts.shapeOutlineColor = cpSpaceDebugColor(r: 255, g: 0, b: 0, a: 120)
    debugOpts.constraintColor = cpSpaceDebugColor(r: 0, g: 255, b: 0, a: 120)
    debugOpts.collisionPointColor = cpSpaceDebugColor(r: 0, g: 0, b: 255, a: 120)
    debugOpts.colorForShape = drawColour
    let flags: DebugDrawFlags = [DebugDrawFlags.Shapes, DebugDrawFlags.Constraints]
    debugOpts.flags = cpSpaceDebugDrawFlags(flags.rawValue)
    debugOpts.drawCircle = drawCircle
    debugOpts.drawSegment = drawSegment
    debugOpts.drawPolygon = drawPolygon
    debugOpts.drawFatSegment = drawFatSegment
    debugOpts.drawDot = drawDot

    debugOpts.data = unsafeBitCast(self, UnsafeMutablePointer<Void>.self)

    return debugOpts
  }

  private func drawCircleTrampoline(pos pos: cpVect,
                                    angle: Double,
                                    radius: Double,
                                    outlineColor: cpSpaceDebugColor,
                                    fillColor: cpSpaceDebugColor) {
    delegate.drawCircle(pos: pos.toVector(), angle: angle, radius: radius, outlineColor: outlineColor.toColour(),
        fillColor: fillColor.toColour())
  }

  private func drawSegmentTrampoline(a a: cpVect,
                                     b: cpVect,
                                     color: cpSpaceDebugColor) {
    delegate.drawSegment(a: a.toVector(), b: b.toVector(), color: color.toColour())
  }

  private func drawPolygonTrampoline(count count: Int32,
                                     verts: UnsafePointer<cpVect>,
                                     radius: Double,
                                     outlineColor: cpSpaceDebugColor,
                                     fillColor: cpSpaceDebugColor) {
    delegate.drawPolygon(count: count,
        //verts: verts,
        radius: radius,
        outlineColor: outlineColor.toColour(),
        fillColor: fillColor.toColour())
  }

  private func drawFatSegmentTrampoline(a a: cpVect,
                                        b: cpVect,
                                        radius: Double,
                                        outlineColor: cpSpaceDebugColor,
                                        fillColor: cpSpaceDebugColor) {
    delegate.drawFatSegment(a: a.toVector(), b: b.toVector(), radius: radius, outlineColor: outlineColor.toColour(),
        fillColor: fillColor.toColour())
  }

  private func drawDotTrampoline(size size: Double,
                                 pos: cpVect,
                                 color: cpSpaceDebugColor) {
    delegate.drawDot(size: size, pos: pos.toVector(), color: color.toColour())
  }

  private func drawColourTrampoline(shape: COpaquePointer) -> cpSpaceDebugColor {
    let colour = delegate.drawColour(shape: shape)

    return cpSpaceDebugColor.fromColour(colour)
  }
}