import SwiftUI
import UIKit
import NHVCore

/// Keep native searchable behavior while placing the sort menu inside its field.
struct SearchSortAccessory: UIViewControllerRepresentable {
    @Binding var selection: GallerySort
    @Binding var text: String
    @Environment(\.locale) private var locale
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark

    func makeUIViewController(context: Context) -> SearchSortController { SearchSortController() }

    func updateUIViewController(_ controller: SearchSortController, context: Context) {
        controller.configure(selection: $selection, text: $text, locale: locale, tint: UIColor(theme.accentColor))
        controller.attach()
    }

    static func dismantleUIViewController(_ controller: SearchSortController, coordinator: ()) {
        controller.detach()
    }
}

final class SearchSortController: UIViewController {
    private let accessory = UIView()
    private let sortButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private weak var field: UISearchTextField?
    private weak var searchController: UISearchController?
    private var originalRightView: UIView?
    private var originalRightMode = UITextField.ViewMode.never
    private var originalClearMode = UITextField.ViewMode.never
    private var selection: Binding<GallerySort>?
    private var text: Binding<String>?
    private var choices: [(value: GallerySort, title: String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        var configuration = UIButton.Configuration.plain()
        configuration.image = Self.funnelImage
        configuration.imagePlacement = .leading
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 13, weight: .medium))
            return attributes
        }
        sortButton.configuration = configuration
        sortButton.addAction(UIAction { [weak self] _ in self?.showSortMenu() }, for: .touchUpInside)
        sortButton.accessibilityIdentifier = "search.sort"
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = .tertiaryLabel
        clearButton.accessibilityIdentifier = "search.clearInput"
        clearButton.addAction(UIAction { [weak self] _ in
            self?.text?.wrappedValue = ""
            self?.field?.text = ""
            self?.layoutAccessory()
        }, for: .touchUpInside)
        accessory.addSubview(clearButton)
        accessory.addSubview(sortButton)
    }

    func configure(selection: Binding<GallerySort>, text: Binding<String>, locale: Locale, tint: UIColor) {
        loadViewIfNeeded()
        self.selection = selection
        self.text = text
        sortButton.tintColor = tint
        sortButton.accessibilityLabel = AppLocalization.string("Sort", locale: locale)
        clearButton.accessibilityLabel = AppLocalization.string("Clear search text", locale: locale)
        let titles: [(GallerySort, String.LocalizationValue)] = [
            (.date, "Newest"), (.popular, "Popular"), (.today, "Today"), (.week, "This Week"), (.month, "This Month")
        ]
        choices = titles.map { ($0.0, AppLocalization.string($0.1, locale: locale)) }
        let selectedTitle = choices.first(where: { $0.value == selection.wrappedValue })?.title
        sortButton.configuration?.title = selectedTitle
        sortButton.configuration?.baseForegroundColor = tint
        sortButton.accessibilityValue = selectedTitle
        layoutAccessory()
    }

    private func showSortMenu() {
        guard let selection, sortButton.window != nil else { return }
        // A button's UIMenu can morph its enclosing iOS glass search field
        // into the menu. A separate popover leaves that field on screen.
        let presenter: UIViewController
        if let searchController, searchController.isActive {
            presenter = searchController
        } else {
            presenter = self
        }
        guard presenter.presentedViewController == nil else { return }
        let menu = SearchSortMenuController(choices: choices, selection: selection.wrappedValue) { [weak self] value in
            self?.selection?.wrappedValue = value
        }
        menu.modalPresentationStyle = .popover
        menu.overrideUserInterfaceStyle = sortButton.traitCollection.userInterfaceStyle
        if let popover = menu.popoverPresentationController {
            popover.sourceView = sortButton
            popover.sourceRect = sortButton.bounds
            popover.permittedArrowDirections = .up
            popover.delegate = menu
        }
        presenter.present(menu, animated: true)
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        attach()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        attach()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        attach()
    }

    func attach() {
        // Attach before navigation/search animations begin. Presentation of a
        // menu is not a reason to tear down the search field's accessory.
        guard isViewLoaded else { return }
        var ancestor = parent
        while let owner = ancestor {
            if let candidate = owner.navigationItem.searchController?.searchBar.searchTextField {
                if field !== candidate {
                    detach()
                    field = candidate
                    searchController = owner.navigationItem.searchController
                    originalRightView = candidate.rightView
                    originalRightMode = candidate.rightViewMode
                    originalClearMode = candidate.clearButtonMode
                }
                if candidate.rightView !== accessory { candidate.rightView = accessory }
                candidate.clearButtonMode = .never
                candidate.rightViewMode = .always
                layoutAccessory()
                return
            }
            ancestor = owner.parent
        }
    }

    func detach() {
        if let field, field.rightView === accessory {
            field.rightView = originalRightView
            field.rightViewMode = originalRightMode
            field.clearButtonMode = originalClearMode
        }
        field = nil
        searchController = nil
        originalRightView = nil
    }

    private func layoutAccessory() {
        let hasText = !(text?.wrappedValue.isEmpty ?? true)
        let buttonWidth = min(144, max(40, ceil(sortButton.intrinsicContentSize.width)))
        let width: CGFloat = buttonWidth + (hasText ? 36 : 0)
        let size = CGSize(width: width, height: 36)
        if accessory.frame.size != size { accessory.frame.size = size }
        clearButton.isHidden = !hasText
        clearButton.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        sortButton.frame = CGRect(x: hasText ? 36 : 0, y: 0, width: buttonWidth, height: 36)
    }

    private static let funnelImage = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 2, y: 3))
        path.addLine(to: CGPoint(x: 18, y: 3))
        path.addLine(to: CGPoint(x: 12, y: 10))
        path.addLine(to: CGPoint(x: 12, y: 16))
        path.addLine(to: CGPoint(x: 8, y: 18))
        path.addLine(to: CGPoint(x: 8, y: 10))
        path.close()
        path.lineWidth = 1.6
        path.lineJoinStyle = .round
        path.stroke()
    }.withRenderingMode(.alwaysTemplate)
}

private final class SearchSortMenuController: UITableViewController, UIPopoverPresentationControllerDelegate {
    private let choices: [(value: GallerySort, title: String)]
    private let selection: GallerySort
    private let onSelect: (GallerySort) -> Void

    init(choices: [(value: GallerySort, title: String)], selection: GallerySort, onSelect: @escaping (GallerySort) -> Void) {
        self.choices = choices
        self.selection = selection
        self.onSelect = onSelect
        super.init(style: .plain)
        let font = UIFont.preferredFont(forTextStyle: .body)
        let rowHeight = max(44, ceil(font.lineHeight) + 22)
        let width = choices.map { SearchSortMenuCell(title: $0.title, selected: false).fittingWidth }.max() ?? 0
        tableView.rowHeight = rowHeight
        tableView.estimatedRowHeight = 0
        preferredContentSize = CGSize(width: width, height: rowHeight * CGFloat(choices.count))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.contentInsetAdjustmentBehavior = .always
        if #available(iOS 26.0, *) {
            tableView.topEdgeEffect.isHidden = true
            tableView.bottomEdgeEffect.isHidden = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Popovers inset the table around their arrow and rounded edges.
        // Include those insets so the first and last rows both fit in full.
        let insets = tableView.adjustedContentInset
        let height = tableView.rowHeight * CGFloat(choices.count) + insets.top + insets.bottom
        if abs(preferredContentSize.height - height) > 0.5 {
            preferredContentSize.height = height
        }
        tableView.isScrollEnabled = tableView.bounds.height + 0.5 < height
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { choices.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let choice = choices[indexPath.row]
        let cell = SearchSortMenuCell(title: choice.title, selected: choice.value == selection)
        cell.backgroundColor = .clear
        cell.tintColor = .label
        cell.accessibilityIdentifier = "search.sort.\(choice.value.rawValue)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect(choices[indexPath.row].value)
        dismiss(animated: true)
    }

    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        .none
    }
}

private final class SearchSortMenuCell: UITableViewCell {
    private static let horizontalInset: CGFloat = 16
    private let row = UIStackView()

    var fittingWidth: CGFloat {
        ceil(row.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width) + Self.horizontalInset * 2
    }

    init(title: String, selected: Bool) {
        super.init(style: .default, reuseIdentifier: nil)
        // UIListContentView can use cap-height bounds that clip CJK glyphs.
        // Lay out a regular label with room for the complete font line instead.
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)))
        checkmark.tintColor = .label
        checkmark.contentMode = .scaleAspectFit
        // Reserve the same measured space in every row. UIKit's accessory
        // reservation otherwise reduces the text width only after selection.
        checkmark.alpha = selected ? 1 : 0
        checkmark.isAccessibilityElement = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.addArrangedSubview(label)
        row.addArrangedSubview(checkmark)
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.horizontalInset),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.horizontalInset),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            checkmark.widthAnchor.constraint(equalToConstant: 22),
            checkmark.heightAnchor.constraint(equalToConstant: 22),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: ceil(label.font.lineHeight) + 6),
        ])
        accessibilityLabel = title
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
