import UIKit

final class TouchTestView: UIView {

  var touches: Set<UITouch> = .init()

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)

    touches.forEach { self.touches.insert($0) }
  }

}
