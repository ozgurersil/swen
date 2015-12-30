//
//   PhyBody.swift created on 30/12/15
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

import CChipmunk

public class PhyBody {
  let handle: COpaquePointer

  public init(fromHandle handle: COpaquePointer) {
    self.handle = handle

    assert(handle != nil, "PhyBody.init(fromHandle:) handed a null handle")
  }

  public convenience init(mass: Double, moment: Double) {
    let ptr = cpBodyNew(mass, moment)

    self.init(fromHandle: ptr)
  }

  public var position: Vector<Double> {
    get {
      return cpBodyGetPosition(self.handle).toVector()
    }
    set {
      cpBodySetPosition(self.handle, cpVect.fromVector(newValue))
    }
  }

  public var velocity: Vector<Double> {
    get {
      return cpBodyGetVelocity(self.handle).toVector()
    }
    set {
      cpBodySetVelocity(self.handle, cpVect.fromVector(newValue))
    }
  }
}