import UIKit

// Custom Window to have proper simulation of presentation and dismissal lifecycle events
final class HammerWindow: UIWindow {
    private let hammerViewController = HammerViewController()

    override var safeAreaInsets: UIEdgeInsets {
        return .zero
    }

    init() {
        super.init(frame: UIScreen.main.bounds)
        self.rootViewController = self.hammerViewController

        if #available(iOS 13.0, *) {
            self.backgroundColor = .systemBackground
        } else {
            self.backgroundColor = .white
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func presentContained(_ viewController: UIViewController) {
        self.makeVisibleAndKey()
        self.hammerViewController.presentContained(viewController)
    }

    func dismissContained() {
        self.hammerViewController.dismissContained()
        self.removeFromScene(removeViewController: false)
    }
}

private final class HammerViewController: UIViewController {
    private let containerView = UIView()

    override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        self.containerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.containerView)

        // We only activate the top and leading constraints to allow the content to size itself.
        NSLayoutConstraint.activate([
            self.containerView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.containerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.containerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.containerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])
    }

    func presentContained(_ viewController: UIViewController) {
        viewController.beginAppearanceTransition(true, animated: false)
        self.addChild(viewController)

        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.containerView.addSubview(viewController.view)
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: self.containerView.topAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor),
        ])

        viewController.didMove(toParent: self)
        viewController.endAppearanceTransition()
        self.view.layoutIfNeeded()
    }

    func dismissContained() {
        for viewController in self.children {
            viewController.beginAppearanceTransition(false, animated: false)
            viewController.willMove(toParent: nil)
            viewController.view.removeFromSuperview()
            viewController.removeFromParent()
            viewController.endAppearanceTransition()
        }
    }
}

extension UIWindow {
    func makeVisibleAndKey(file: StaticString = #file, line: UInt = #line) {
        self.addToMainSceneIfNeeded(file: file, line: line)
        self.makeKeyAndVisible()
    }

    func addToMainSceneIfNeeded(file: StaticString = #file, line: UInt = #line) {
        guard #available(iOS 13.0, *) else {
            return
        }

        guard self.windowScene == nil else {
            return
        }

        if let mainScene = UIScene.mainOrFirstConnectedScene {
            self.windowScene = mainScene
        } else {
            assertionFailure("Unable to find main scene", file: file, line: line)
        }
    }

    func removeFromScene(removeViewController: Bool = true) {
        self.isHidden = true

        if #available(iOS 13.0, *) {
            self.windowScene = nil
        }

        if removeViewController {
            self.rootViewController = nil
        }
    }
}

@available(iOS 13.0, *)
private extension UIScene {
    static var mainOrFirstConnectedScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.screen == UIScreen.main } ?? scenes.first
    }
}
