import Foundation
import Hammer
import UIKit
import XCTest

final class ViewControllerTests: XCTestCase {
    func testSignIn() throws {
        let viewController = TestSignInViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        let eventGenerator = try EventGenerator(viewController: navigationController)
        try eventGenerator.waitUntilHittable("username_field", timeout: 1)

        let usernameTextField = try eventGenerator.viewWithIdentifier("username_field",
                                                                      ofType: UITextField.self)
        let passwordTextField = try eventGenerator.viewWithIdentifier("password_field",
                                                                      ofType: UITextField.self)
        let signInButton = try eventGenerator.viewWithIdentifier("signin_button",
                                                                 ofType: UIButton.self)

        try eventGenerator.fingerTap(at: "username_field")
        XCTAssertTrue(usernameTextField.isFirstResponder)
        try eventGenerator.keyType("GabrielUsername123")
        XCTAssertEqual(usernameTextField.text, "GabrielUsername123")
        try eventGenerator.keyPress(.returnOrEnter)
        XCTAssertTrue(passwordTextField.isFirstResponder)
        XCTAssertFalse(signInButton.isEnabled)
        try eventGenerator.keyType("$eCr3tP@ss!")
        XCTAssertEqual(passwordTextField.text, "$eCr3tP@ss!")
        XCTAssertTrue(signInButton.isEnabled)
        try eventGenerator.keyPress(.returnOrEnter)

        try eventGenerator.waitUntilExists("username_label", timeout: 1)
        let usernameLabel = try eventGenerator.viewWithIdentifier("username_label", ofType: UILabel.self)

        XCTAssertEqual(usernameLabel.text, "Hello GabrielUsername123")
    }
}

private final class TestSignInViewController: UIViewController, UITextFieldDelegate {
    let usernameTextField: UITextField = {
        let view = UITextField()
        view.disablePredictiveBar()
        view.accessibilityIdentifier = "username_field"
        view.borderStyle = .roundedRect
        view.placeholder = "Username"
        return view
    }()

    let passwordTextField: UITextField = {
        let view = UITextField()
        view.disablePredictiveBar()
        view.accessibilityIdentifier = "password_field"
        view.borderStyle = .roundedRect
        view.placeholder = "Password"
        view.isSecureTextEntry = true
        return view
    }()

    let signInButton: UIButton = {
        let view = UIButton()
        view.accessibilityIdentifier = "signin_button"
        view.setTitle("Sign In", for: .normal)
        view.layer.cornerRadius = 8
        view.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.layoutMargins = UIEdgeInsets(top: 40, left: 16, bottom: 40, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: self.view.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])

        let titleLabel = UILabel()
        titleLabel.text = "Welcome to Hammer!"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        stackView.addArrangedSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Please sign in"
        subtitleLabel.font = .systemFont(ofSize: 16)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.setCustomSpacing(24, after: subtitleLabel)

        self.usernameTextField.delegate = self
        self.usernameTextField.addTarget(self, action: #selector(self.updateButton), for: .editingChanged)
        stackView.addArrangedSubview(self.usernameTextField)

        self.passwordTextField.delegate = self
        self.passwordTextField.addTarget(self, action: #selector(self.updateButton), for: .editingChanged)
        stackView.addArrangedSubview(self.passwordTextField)

        stackView.addArrangedSubview(UIView()) // Stretchy spacer

        self.signInButton.addTarget(self, action: #selector(self.performSignIn), for: .touchUpInside)
        stackView.addArrangedSubview(self.signInButton)

        self.updateButton()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.usernameTextField {
            self.passwordTextField.becomeFirstResponder()
        } else if textField == self.passwordTextField {
            self.performSignIn()
        }

        return false
    }

    @objc
    private func updateButton() {
        let isUsernameEmpty = self.usernameTextField.text?.isEmpty ?? true
        let isPasswordEmpty = self.passwordTextField.text?.isEmpty ?? true
        let isEnabled = !isUsernameEmpty && !isPasswordEmpty
        self.signInButton.isEnabled = isEnabled
        self.signInButton.backgroundColor = isEnabled ? .systemGreen : .lightGray
    }

    @objc
    private func performSignIn() {
        self.resignFirstResponder()

        let profileViewController = TestProfileViewController(username: self.usernameTextField.text ?? "Err")
        self.navigationController?.pushViewController(profileViewController, animated: true)
    }
}

private final class TestProfileViewController: UIViewController {
    private let username: String

    init(username: String) {
        self.username = username
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }

        let titleLabel = UILabel()
        titleLabel.text = "Hello \(self.username)"
        titleLabel.accessibilityIdentifier = "username_label"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
        ])
    }
}
