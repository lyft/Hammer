import UIKit

private var kActionKey: UInt8 = 0

private final class ActionWrapper {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc
    func invoke() {
        self.action()
    }
}

extension UIControl {
    private var actionWrappers: [ActionWrapper] {
        get { objc_getAssociatedObject(self, &kActionKey) as? [ActionWrapper] ?? [] }
        set { objc_setAssociatedObject(self, &kActionKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func addHandler(forEvent event: Event, action: @escaping () -> Void) {
        let target = ActionWrapper(action: action)
        self.addTarget(target, action: #selector(ActionWrapper.invoke), for: event)
        self.actionWrappers.append(target)
    }
}

extension UIGestureRecognizer {
    private var actionWrappers: [ActionWrapper] {
        get { objc_getAssociatedObject(self, &kActionKey) as? [ActionWrapper] ?? [] }
        set { objc_setAssociatedObject(self, &kActionKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func addHandler(forState state: State, action: @escaping () -> Void) {
        let target = ActionWrapper { [weak self] in
            if let this = self, this.state == state {
                action()
            }
        }

        self.addTarget(target, action: #selector(ActionWrapper.invoke))
        self.actionWrappers.append(target)
    }
}
