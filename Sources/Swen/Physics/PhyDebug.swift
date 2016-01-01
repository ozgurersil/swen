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
  func drawCircle(pos pos: Vector, angle: Double, radius: Double, outlineColor: Colour, fillColor: Colour)

  func drawSegment(a a: Vector, b: Vector, color: Colour)

  func drawFatSegment(a a: Vector, b: Vector, radius: Double, outlineColor: Colour, fillColor: Colour)

  func drawPolygon(count count: Int32, verts: Array<Vector>, radius: Double, outlineColor: Colour, fillColor: Colour)

  func drawDot(size size: Double, pos: Vector, color: Colour)

  func drawColour(shape shape: COpaquePointer) -> Colour
}

// Why not generics? Closures can't capture generic classes.
public final class PhyDebug: AnyObject {
  let delegate: PhyDebugDrawDelegate

  public init(delegate: PhyDebugDrawDelegate) {
    self.delegate = delegate
  }

  public func generateStruct() -> cpSpaceDebugDrawOptions {
    var debugOpts: cpSpaceDebugDrawOptions = cpSpaceDebugDrawOptions()

    /* Trampolines from c back into swift world */
    let drawSegment: cpSpaceDebugDrawSegmentImpl = {
      (a: cpVect,
       b: cpVect,
       color: cpSpaceDebugColor,
       data: cpDataPointer) -> Void in

      let klass = unsafeBitCast(data, PhyDebug.self)
      klass.drawSegmentTrampoline(a: a, b: b, color: color)
    }

    let drawCircle: cpSpaceDebugDrawCircleImpl = {
      (pos: cpVect,
       angle: Double,
       radius: Double,
       outlineColor: cpSpaceDebugColor,
       fillColor: cpSpaceDebugColor,
       data: cpDataPointer) in

      let klass = unsafeBitCast(data, PhyDebug.self)
      klass.drawCircleTrampoline(pos: pos, angle: angle, radius: radius, outlineColor: outlineColor,
          fillColor: fillColor)
    }

    let drawPolygon: cpSpaceDebugDrawPolygonImpl = {
      (count: Int32,
       verts: UnsafePointer<cpVect>,
       radius: Double,
       outlineColor: cpSpaceDebugColor,
       fillColor: cpSpaceDebugColor,
       data: cpDataPointer) in

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

      let klass = unsafeBitCast(data, PhyDebug.self)
      klass.drawFatSegmentTrampoline(a: a, b: b, radius: radius, outlineColor: outlineColor, fillColor: fillColor)
    }

    let drawDot: cpSpaceDebugDrawDotImpl = {
      (size: Double,
       pos: cpVect,
       color: cpSpaceDebugColor,
       data: cpDataPointer) in

      let klass = unsafeBitCast(data, PhyDebug.self)
      klass.drawDotTrampoline(size: size, pos: pos, color: color)
    }

    let drawColour: cpSpaceDebugDrawColorForShapeImpl = {
      (shape: COpaquePointer,
       data: cpDataPointer) in

      let klass = unsafeBitCast(data, PhyDebug.self)
      let colour = klass.drawColourTrampoline(shape)
      return colour
    }

    debugOpts.shapeOutlineColor = cpSpaceDebugColor.fromColour(Colour.green)
    debugOpts.constraintColor = cpSpaceDebugColor.fromColour(Colour.green)
    debugOpts.collisionPointColor = cpSpaceDebugColor.fromColour(Colour.green)
    debugOpts.colorForShape = drawColour
    let flags: DebugDrawFlags = [DebugDrawFlags.Shapes, DebugDrawFlags.CollisionPoints, DebugDrawFlags.Constraints]
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

    var vectors: Array<Vector> = Array<Vector>()

    for i in Range(start: 0, end: Int(count)) {
      let vect: UnsafePointer<cpVect> = verts.advancedBy(i)
      vectors.append(vect.memory.toVector())
    }

    delegate.drawPolygon(count: count,
        verts: vectors,
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

public class PhysicsDebugger : PhyDebugDrawDelegate {
  let renderer : Renderer

  public init(withRenderer: Renderer) {
    self.renderer = withRenderer
  }

  public func drawSegment(a a: Vector, b: Vector, color: Colour) {
    renderer.drawColour = color
    renderer.draw(startingFrom: a, endingAt: b)
  }

  public func drawDot(size size: Double, pos: Vector, color: Colour) {
    renderer.fillCircle(position: pos, rad: size.int16, colour: color)
  }

  public func drawCircle(pos pos: Vector,
                         angle: Double,
                         radius: Double,
                         outlineColor: Colour,
                         fillColor: Colour) {
    renderer.fillCircle(position: pos, rad: radius.int16, colour: fillColor)
    renderer.drawCircle(position: pos, rad: radius.int16, colour: outlineColor)

  }

  public func drawColour(shape shape: COpaquePointer) -> Colour {
    return Colour.red.alpha(100)
  }

  public func drawFatSegment(a a: Vector,
                             b: Vector,
                             radius: Double,
                             outlineColor: Colour,
                             fillColor: Colour) {

    let n = (b - a).rperp.normalize
    let t = n.rperp

    var r = radius + 1.0
    if r <= 1.0 {
      r = 1.0
    }

    let nw = n.mult(r)
    let tw = t.mult(r)

    let v0 = b - (nw + tw)
    let v1 = b + (nw - tw)
    let v2 = b - nw
    let v3 = b + nw
    let v4 = a - nw
    let v5 = a + nw
    let v6 = a - (nw - tw)
    let v7 = a + (nw + tw)

    renderer.fillTrigon(point1: v0, point2: v1, point3: v2, colour: fillColor)
    renderer.fillTrigon(point1: v3, point2: v1, point3: v2, colour: fillColor)
    renderer.fillTrigon(point1: v3, point2: v4, point3: v2, colour: fillColor)
    renderer.fillTrigon(point1: v3, point2: v4, point3: v5, colour: fillColor)
    renderer.fillTrigon(point1: v6, point2: v4, point3: v5, colour: fillColor)
    renderer.fillTrigon(point1: v6, point2: v7, point3: v5, colour: fillColor)

    renderer.drawAATrigon(point1: v0, point2: v1, point3: v2, colour: outlineColor)
    renderer.drawAATrigon(point1: v3, point2: v1, point3: v2, colour: outlineColor)
    renderer.drawAATrigon(point1: v3, point2: v4, point3: v2, colour: outlineColor)
    renderer.drawAATrigon(point1: v3, point2: v4, point3: v5, colour: outlineColor)
    renderer.drawAATrigon(point1: v6, point2: v4, point3: v5, colour: outlineColor)
    renderer.drawAATrigon(point1: v6, point2: v7, point3: v5, colour: outlineColor)

    // renderer.fillThickLine(point1: v1, point2: v2, width: 6, colour: Colour.red)
    // renderer.fillThickLine(point1: v2, point2: v3, width: 6, colour: Colour.red)
    // renderer.fillThickLine(point1: v3, point2: v4, width: 6, colour: Colour.red)
    // renderer.fillThickLine(point1: v4, point2: v5, width: 6, colour: Colour.red)
    // renderer.fillThickLine(point1: v5, point2: v6, width: 6, colour: Colour.red)
    // renderer.fillThickLine(point1: v6, point2: v7, width: 6, colour: Colour.red)
    // renderer.fillThickLine(point1: v7, point2: v1, width: 6, colour: Colour.red)

    // print(v0, v1, v2, v3, v4, v5, v6, v7)

    // Just drawing a line, rotating segments is too much effort.
    // print("\(a) -> \(b)")

    // renderer.drawColour = outlineColor
    // renderer.draw(startingFrom: a, endingAt: b)
    // renderer.drawColour = Colour.lightGreen
    // renderer.fill(usingRect: Rect(x: a.x, y: a.y, sizeX: b.x, sizeY: b.y))
    // renderer.fillThickLine(point1: a, point2: b, width: 3, colour: fillColor)
    // renderer.fillThickLine(point1: b, point2: a, width: 2, colour: outlineColor)
    // print(fillColor)
    // print(outlineColor)

    // renderer.fillRoundedRectangle(point1: a, point2: a + b, radius: radius.int16, colour: fillColor)

    // renderer.fillRoundedRectangle(point1: a, point2: b, radius: radius.int16, colour: fillColor)
    // renderer.drawRoundedRectangle(point1: a, point2: b, radius: radius.int16, colour: outlineColor)
  }

  public func drawPolygon(count count: Int32,
                          verts: Array<Vector>,
                          radius: Double,
                          outlineColor: Colour,
                          fillColor: Colour) {
    let vx = verts.map { $0.x.int16 }
    let vy = verts.map { $0.y.int16 }

    renderer.fillPolygon(vx: vx, vy: vy, colour: fillColor)
    renderer.drawPolygon(vx: vx, vy: vy, colour: outlineColor)
  }
}