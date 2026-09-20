#if targetEnvironment(macCatalyst)
import SwiftUI
import UIKit

struct ReaderKeyboardControls: UIViewControllerRepresentable {
    let isEnabled: Bool
    let turnPage: (Int) -> Void

    func makeUIViewController(context: Context) -> ReaderKeyboardController {
        ReaderKeyboardController()
    }

    func updateUIViewController(_ controller: ReaderKeyboardController, context: Context) {
        controller.turnPage = turnPage
        controller.isEnabled = isEnabled
        controller.updateResponder()
    }

    static func dismantleUIViewController(_ controller: ReaderKeyboardController, coordinator: ()) {
        controller.isEnabled = false
        controller.turnPage = nil
        controller.resignFirstResponder()
    }
}

final class ReaderKeyboardController: UIViewController {
    var isEnabled = false
    var turnPage: ((Int) -> Void)?

    override var canBecomeFirstResponder: Bool { isEnabled }

    override var keyCommands: [UIKeyCommand]? {
        guard isEnabled else { return [] }
        return [UIKeyCommand.inputLeftArrow, UIKeyCommand.inputUpArrow,
                UIKeyCommand.inputRightArrow, UIKeyCommand.inputDownArrow, " "].map { input in
            let command = UIKeyCommand(input: input, modifierFlags: [], action: #selector(turnPageFromKey(_:)))
            // Catalyst otherwise reserves arrows for focus navigation and scrolling.
            command.wantsPriorityOverSystemBehavior = true
            return command
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        resignFirstResponder()
        super.viewWillDisappear(animated)
    }

    func updateResponder() {
        if isEnabled, viewIfLoaded?.window != nil {
            becomeFirstResponder()
        } else if !isEnabled {
            resignFirstResponder()
        }
    }

    @objc private func turnPageFromKey(_ command: UIKeyCommand) {
        guard isEnabled else { return }
        let previous = command.input == UIKeyCommand.inputLeftArrow || command.input == UIKeyCommand.inputUpArrow
        turnPage?(previous ? -1 : 1)
    }
}
#endif
