import UIKit

/// Remembers how to undo the changes commands make to views and constraints, so clients can try changes
/// and revert them.
///
/// Only the first change to each property is kept, so reverting restores the original value rather than
/// the one before the last change.
@MainActor
final class ChangeLog {
    private struct Change {
        let key: String
        weak var object: AnyObject?
        /// The view the change belongs to, to revert the changes of one view.
        weak var view: UIView?
        let summary: String
        let undo: @MainActor () -> Void
    }

    private var changes = [Change]()

    /// Records a change before it is made.
    ///
    /// - parameter object:  The changed object, such as a view or a constraint.
    /// - parameter key:     What changed on the object, such as the property name.
    /// - parameter view:    The view the change belongs to.
    /// - parameter summary: What the change is, to report it when reverting.
    /// - parameter undo:    Restores the original state.
    func record(_ object: AnyObject, key: String, view: UIView?, summary: String,
                undo: @escaping @MainActor () -> Void)
    {
        let key = "\(ObjectIdentifier(object)).\(key)"
        guard !self.changes.contains(where: { $0.key == key && $0.object === object }) else {
            return
        }

        self.changes.append(Change(key: key, object: object, view: view, summary: summary, undo: undo))
    }

    /// Undoes the changes, newest first.
    ///
    /// - parameter view: The view to revert the changes of, or nil for every change.
    ///
    /// - returns: The summaries of the reverted changes.
    func revert(view: UIView?) -> [String] {
        let isReverted = { (change: Change) in view == nil || change.view === view }
        let reverted = self.changes.filter(isReverted).filter { $0.object != nil }.reversed()
        reverted.forEach { $0.undo() }
        self.changes.removeAll(where: isReverted)
        return reverted.map(\.summary)
    }
}
