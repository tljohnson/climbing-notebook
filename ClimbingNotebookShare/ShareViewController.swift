import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let button = UIButton(type: .system)
        button.setTitle("Import unavailable in foundation build. Close", for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    @objc private func close() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.climbingnotebook.foundation", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Nothing was imported. Intake is not implemented."]
        ))
    }
}
