import UIKit

final class TouchTestView: UIView {

  var touches: Set<UITouch> = .init()
  var movedTouches: Set<UITouch> = .init()
  var endedTouches: Set<UITouch> = .init()

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)

    touches.forEach { self.touches.insert($0) }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)

    touches.forEach { self.movedTouches.insert($0) }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)

    touches.forEach { self.endedTouches.insert($0) }
  }

}
