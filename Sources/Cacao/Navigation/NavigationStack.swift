//
//  NavigationStack.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - NavigationPath

/// A type-erased list of data representing the content of a navigation stack.
public struct NavigationPath: Equatable {

    internal var elements: [AnyHashable]

    /// Creates a new, empty navigation path.
    public init() {
        self.elements = []
    }

    /// Creates a new navigation path from the contents of a sequence.
    public init<S: Sequence>(_ elements: S) where S.Element: Hashable {
        self.elements = elements.map { AnyHashable($0) }
    }

    /// The number of elements in this path.
    public var count: Int { elements.count }

    /// A Boolean that indicates whether this path is empty.
    public var isEmpty: Bool { elements.isEmpty }

    /// Appends a new value to the end of this path.
    public mutating func append<V: Hashable>(_ value: V) {
        elements.append(AnyHashable(value))
    }

    /// Removes values from the end of this path.
    public mutating func removeLast(_ k: Int = 1) {
        elements.removeLast(min(k, elements.count))
    }
}

// MARK: - Navigation model

/// What a navigation stack shows above its root.
internal enum NavigationEntry {

    /// A value, shown with the destination registered for its type.
    case value(AnyHashable)

    /// A view, from a link with a destination.
    case view(AnyView, id: Int)
}

/// A navigation stack's state and the actions views inside it use.
@MainActor
internal final class NavigationContext {

    /// The stack's path, for a stack bound to one.
    var path: Binding<[AnyHashable]>?

    /// The entries of a stack without a path, and views pushed by links
    /// with destinations above a bound path.
    var ownEntries: [NavigationEntry] = []

    /// Called when the entries change, to update the stack.
    var onChange: () -> Void = { }

    /// Destinations by the type of the values they show.
    var destinations: [ObjectIdentifier: (AnyHashable) -> AnyView] = [:]

    /// The context of each screen, by depth.
    var screens: [Int: ScreenContext] = [:]

    /// The split view this stack is a column of, if any.
    var split: SplitLink?

    /// Whether this stack is a split view's detail column.
    var isDetail = false

    /// For a split view's sidebar: the detail column's context, which links
    /// in the sidebar show their destinations in.
    var detail: NavigationContext? {
        isDetail ? nil : split?.detail
    }

    private var nextViewID = 0

    /// The number of screens above the root at the last update.
    var lastDepth: Int?

    var entries: [NavigationEntry] {
        (path?.wrappedValue.map { .value($0) } ?? []) + ownEntries
    }

    func push(value: AnyHashable) {
        if let detail {
            detail.replace(with: .value(value))
            return
        }
        if let path {
            path.wrappedValue.append(value)
        } else {
            ownEntries.append(.value(value))
        }
        onChange()
    }

    func push(view: AnyView) {
        nextViewID += 1
        let entry = NavigationEntry.view(view, id: nextViewID)
        if let detail {
            detail.replace(with: entry)
            return
        }
        ownEntries.append(entry)
        onChange()
    }

    /// Shows only an entry above the root, for a split view's detail.
    func replace(with entry: NavigationEntry) {
        if let path {
            if case let .value(value) = entry {
                path.wrappedValue = [value]
                ownEntries = []
            } else {
                path.wrappedValue = []
                ownEntries = [entry]
            }
        } else {
            ownEntries = [entry]
        }
        onChange()
    }

    /// Pops screens until `depth` screens remain above the root.
    func pop(to depth: Int) {
        var excess = entries.count - depth
        guard excess > 0 else { return }
        let own = min(excess, ownEntries.count)
        ownEntries.removeLast(own)
        excess -= own
        if excess > 0, let path {
            path.wrappedValue.removeLast(min(excess, path.wrappedValue.count))
        }
        onChange()
    }

    func destination(for value: AnyHashable) -> AnyView? {
        let key = ObjectIdentifier(type(of: value.base))
        // A split view's detail shows destinations its sidebar registered.
        let destination = destinations[key] ?? split?.sidebar?.destinations[key]
        return destination.map { $0(value) }
    }
}

/// Connects a split view's sidebar and detail columns.
@MainActor
internal final class SplitLink {
    weak var sidebar: NavigationContext?
    weak var detail: NavigationContext?

    /// The widths that columns' views set, by column.
    var widths: [String: SplitColumnWidth] = [:]

    /// The widths columns were dragged to, by column.
    var draggedWidths: [String: CGFloat] = [:]

    /// The visibility shown when there's no binding to it.
    var visibility = NavigationSplitViewVisibility.automatic

    /// Sets the visibility: through the binding if there is one.
    var setVisibility: (NavigationSplitViewVisibility) -> Void = { _ in }

    /// The visibility shown now.
    var currentVisibility = NavigationSplitViewVisibility.automatic

    var hasContentColumn = false

    /// Whether a column's views removed the sidebar toggle.
    var removesSidebarToggle = false

    /// The split view's node, to update when its state changes.
    weak var node: ViewNode?

    /// The width of a column: dragged, or set by its views, or `width`.
    func width(of column: String, default width: CGFloat?) -> CGFloat? {
        if let dragged = draggedWidths[column] {
            return dragged
        }
        return widths[column]?.width ?? width
    }

    /// The narrowest and widest a column can be dragged.
    func range(of column: String) -> ClosedRange<CGFloat> {
        let set = widths[column]
        let lower = set?.min ?? 150
        return lower...max(lower, set?.max ?? 500)
    }

    /// Shows the sidebar if it's hidden, or hides it.
    func toggleSidebar() {
        let showsSidebar = currentVisibility.showsColumns(hasContent: hasContentColumn)[0]
        let next: NavigationSplitViewVisibility = showsSidebar
            ? (hasContentColumn ? .doubleColumn : .detailOnly)
            : .all
        withAnimation {
            setVisibility(next)
        }
    }
}

/// What the views of one screen set for its navigation bar.
@MainActor
internal final class ScreenContext {

    var title: String = ""

    /// Toolbar content, by the node of the modifier that set it.
    var toolbars: [Int: AnyView] = [:]

    var isBackButtonHidden = false

    var search: (text: Binding<String>, prompt: Text?)?

    /// The bar, to update when what the screen sets changes.
    weak var barNode: ViewNode?

    func barNeedsUpdate() {
        barNode?.invalidate()
    }
}

private struct NavigationContextKey: EnvironmentKey {
    static var defaultValue: NavigationContext? { nil }
}

private struct ScreenContextKey: EnvironmentKey {
    static var defaultValue: ScreenContext? { nil }
}

extension EnvironmentValues {

    internal var navigationContext: NavigationContext? {
        get { self[NavigationContextKey.self] }
        set { self[NavigationContextKey.self] = newValue }
    }

    internal var screenContext: ScreenContext? {
        get { self[ScreenContextKey.self] }
        set { self[ScreenContextKey.self] = newValue }
    }
}

// MARK: - NavigationStack

/// A view that displays a root view and enables you to present additional
/// views over the root view.
public struct NavigationStack<Data, Root: View>: View {

    internal let path: Binding<[AnyHashable]>?

    internal let root: Root

    public var body: some View {
        _NavigationStack(path: path, root: AnyView(root), column: nil)
    }
}

extension NavigationStack where Data == NavigationPath {

    /// Creates a navigation stack that manages its own navigation state.
    public init(@ViewBuilder root: () -> Root) {
        self.path = nil
        self.root = root()
    }

    /// Creates a navigation stack with heterogeneous navigation state that
    /// you can control.
    public init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) {
        self.path = Binding(
            get: { path.wrappedValue.elements },
            set: { path.wrappedValue.elements = $0 }
        )
        self.root = root()
    }
}

extension NavigationStack where Data: MutableCollection, Data: RandomAccessCollection, Data: RangeReplaceableCollection, Data.Element: Hashable {

    /// Creates a navigation stack with homogeneous navigation state that you
    /// can control.
    public init(path: Binding<Data>, @ViewBuilder root: () -> Root) {
        self.path = Binding(
            get: { path.wrappedValue.map { AnyHashable($0) } },
            set: { path.wrappedValue = Data($0.compactMap { $0.base as? Data.Element }) }
        )
        self.root = root()
    }
}

/// A navigation stack's screens: the root and an entry per pushed screen,
/// all kept, only the top one shown.
internal struct _NavigationStack: View, PrimitiveView {

    let path: Binding<[AnyHashable]>?

    let root: AnyView

    /// The column of a split view this stack is, if any.
    let column: (link: SplitLink, isDetail: Bool)?

    func resolve(in context: ResolveContext) -> Resolution {
        let node = context.node
        let navigation: NavigationContext
        if let existing = node.dynamicStorage["navigation"] as? NavigationContext {
            navigation = existing
        } else {
            navigation = NavigationContext()
            node.dynamicStorage["navigation"] = navigation
        }
        navigation.path = path
        navigation.onChange = { [weak node] in node?.invalidate() }
        if let column {
            navigation.split = column.link
            navigation.isDetail = column.isDetail
            if column.isDetail {
                column.link.detail = navigation
            } else {
                column.link.sidebar = navigation
            }
        }
        var environment = context.environment
        environment.navigationContext = navigation
        let entries = navigation.entries
        var children = [ChildView(
            key: "root",
            view: _NavigationScreen(content: root, depth: 0, navigation: navigation, isDetailRoot: column?.isDetail ?? false),
            environment: environment
        )]
        for (index, entry) in entries.enumerated() {
            let depth = index + 1
            let content: AnyView
            let key: AnyHashable
            switch entry {
            case let .value(value):
                content = AnyView(_DestinationView(value: value, navigation: navigation))
                key = AnyHashable("\(depth) \(value)")
            case let .view(view, id):
                content = view
                key = AnyHashable("\(depth) view \(id)")
            }
            // Pushed screens slide in from the trailing edge, over the last.
            children.append(ChildView(
                key: key,
                view: _NavigationScreen(content: content, depth: depth, navigation: navigation, isDetailRoot: false)
                    .transition(.move(edge: .trailing)),
                environment: environment
            ))
        }
        navigation.screens = navigation.screens.filter { $0.key <= entries.count }
        var resolution = Resolution(behavior: NavigationStackBehavior(), children: children)
        // Pushing and popping animate, except a split view's detail.
        if let last = navigation.lastDepth, last != entries.count, column?.isDetail != true {
            resolution.transaction = { $0.animateByDefault(.smooth(duration: 0.35)) }
        }
        navigation.lastDepth = entries.count
        return resolution
    }

    typealias Body = Never
}

/// Shows the destination registered for a value's type, looked up when it
/// resolves: after the screens below it registered their destinations.
internal struct _DestinationView: View, PrimitiveView {

    let value: AnyHashable

    let navigation: NavigationContext

    func resolve(in context: ResolveContext) -> Resolution {
        let view = navigation.destination(for: value) ?? AnyView(
            Text("No destination for \(String(describing: type(of: value.base)))")
                .foregroundStyle(.secondary)
        )
        return Resolution(children: [ChildView(key: ObjectIdentifier(type(of: value.base)), view: view)])
    }

    typealias Body = Never
}

/// Lays out every screen in the stack's bounds, and shows the top one.
internal struct NavigationStackBehavior: NodeBehavior {

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        let top = LazyProxyTop(node)
        return top?.size(in: proposal) ?? proposal.replacingUnspecifiedDimensions(by: .zero)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        for proxy in node.layoutChildren {
            proxy.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }

    /// The top screen, over the one below while it slides in.
    func displayOrder(of children: [ViewNode]) -> [ViewNode] {
        guard let top = children.last else { return [] }
        if children.count > 1, top.graph.nodeAnimations[top.id]?.transition != nil {
            return [children[children.count - 2], top]
        }
        return [top]
    }
}

@MainActor
private func LazyProxyTop(_ node: ViewNode) -> LayoutProxy? {
    LayoutProxy.combining(node.layoutChildren(ofChildAt: node.children.count - 1))
}

// MARK: - Screen

/// A screen of a navigation stack: its content under a navigation bar that
/// shows what the content sets: title, toolbar and search.
internal struct _NavigationScreen: View, PrimitiveView {

    let content: AnyView

    let depth: Int

    let navigation: NavigationContext

    /// Whether this is a split view detail's root, which has no title bar
    /// unless its content sets one.
    let isDetailRoot: Bool

    func resolve(in context: ResolveContext) -> Resolution {
        let node = context.node
        let screen: ScreenContext
        if let existing = node.dynamicStorage["screen"] as? ScreenContext {
            screen = existing
        } else {
            screen = ScreenContext()
            node.dynamicStorage["screen"] = screen
        }
        navigation.screens[depth] = screen
        var environment = context.environment
        environment.screenContext = screen
        // The content first, so it sets the bar's title and items before the
        // bar resolves.
        return Resolution(
            behavior: NavigationScreenBehavior(),
            children: [
                ChildView(key: "content", view: content, environment: environment),
                ChildView(key: "bar", view: _NavigationBar(screen: screen, navigation: navigation, depth: depth))
            ]
        )
    }

    typealias Body = Never
}

/// Places the bar at the top and the content below it.
internal struct NavigationScreenBehavior: NodeBehavior {

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 320, height: 480))
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        var barHeight: CGFloat = 0
        if let bar = LazyProxy(node, 1) {
            barHeight = bar.size(in: ProposedViewSize(width: bounds.width, height: nil)).height
            bar.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: barHeight))
        }
        if let content = LazyProxy(node, 0) {
            let size = CGSize(width: bounds.width, height: max(bounds.height - barHeight, 0))
            let contentSize = content.size(in: ProposedViewSize(size))
            // Content smaller than the area is centered, like a window's.
            content.place(
                at: CGPoint(
                    x: bounds.minX + (size.width - contentSize.width) / 2,
                    y: bounds.minY + barHeight + (size.height - contentSize.height) / 2
                ),
                proposal: ProposedViewSize(size)
            )
        }
    }

    func displayOrder(of children: [ViewNode]) -> [ViewNode] {
        children
    }
}

@MainActor
private func LazyProxy(_ node: ViewNode, _ index: Int) -> LayoutProxy? {
    LayoutProxy.combining(node.layoutChildren(ofChildAt: index))
}

// MARK: - Bar

/// A navigation bar: back button, title, toolbar items and search.
internal struct _NavigationBar: View, PrimitiveView {

    let screen: ScreenContext

    let navigation: NavigationContext

    let depth: Int

    func resolve(in context: ResolveContext) -> Resolution {
        screen.barNode = context.node
        var items = screen.toolbars.sorted { $0.key < $1.key }.flatMap { toolbarItems(in: $0.value) }
        // A split view's detail shows a button that shows or hides the sidebar.
        if depth == 0, navigation.isDetail, let split = navigation.split, !split.removesSidebarToggle {
            let toggle = Button(action: { split.toggleSidebar() }) {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Toggle Sidebar")
            items.insert(ToolbarItemEntry(placement: .navigation, content: AnyView(toggle)), at: 0)
        }
        let hasContent = !screen.title.isEmpty || !items.isEmpty || screen.search != nil
            || (depth > 0 && !screen.isBackButtonHidden)
        guard hasContent else {
            return Resolution(children: [])
        }
        let previousTitle = navigation.screens[depth - 1]?.title ?? ""
        // A split view's detail shows its sidebar's selection without a way back.
        let showsBack = depth > 0 && !screen.isBackButtonHidden && !(depth == 1 && navigation.isDetail)
        let navigation = self.navigation
        let depth = self.depth
        let bar = _NavigationBarContent(
            title: screen.title,
            backTitle: showsBack ? (previousTitle.isEmpty ? "Back" : previousTitle) : nil,
            back: { navigation.pop(to: depth - 1) },
            leading: items.filter { $0.placement.position == .leading }.map(\.content),
            principal: items.filter { $0.placement.position == .principal }.map(\.content),
            trailing: items.filter { $0.placement.position == .trailing }.map(\.content),
            search: screen.search
        )
        return Resolution(children: [ChildView(key: 0, view: bar)])
    }

    typealias Body = Never
}

private struct _NavigationBarContent: View {

    let title: String

    let backTitle: String?

    let back: () -> Void

    let leading: [AnyView]

    let principal: [AnyView]

    let trailing: [AnyView]

    let search: (text: Binding<String>, prompt: Text?)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 12) {
                    if let backTitle {
                        Button(action: back) {
                            HStack(spacing: 4) {
                                _ChevronShape(pointsDown: false, pointsLeft: true)
                                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                    .frame(width: 10, height: 14)
                                Text(backTitle)
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                    ForEach(leading.indices, id: \.self) { leading[$0] }
                    Spacer(minLength: 0)
                    ForEach(trailing.indices, id: \.self) { trailing[$0] }
                }
                if !principal.isEmpty {
                    HStack { ForEach(principal.indices, id: \.self) { principal[$0] } }
                } else if !title.isEmpty {
                    // Clear of the items on either side.
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.horizontal, leading.isEmpty && trailing.isEmpty && backTitle == nil ? 0 : 90)
                }
            }
            .frame(minHeight: 32)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            if let search {
                TextField("Search", text: search.text, prompt: search.prompt ?? Text("Search"))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            Divider()
        }
        .background(Color.barBackground(colorScheme))
    }
}

extension Color {

    /// The background of navigation and tab bars.
    internal static func barBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97)
    }
}

// MARK: - NavigationLink

/// A view that controls a navigation presentation.
public struct NavigationLink<Label: View, Destination: View>: View {

    internal enum Target {
        case value(AnyHashable?)
        case destination(Destination)
    }

    internal let target: Target

    internal let label: Label

    @Environment(\.navigationContext) private var navigation

    /// Creates a navigation link that presents the destination view.
    public init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
        self.target = .destination(destination())
        self.label = label()
    }

    /// Creates a navigation link that presents the destination view.
    public init(destination: Destination, @ViewBuilder label: () -> Label) {
        self.target = .destination(destination)
        self.label = label()
    }

    public var body: some View {
        let navigation = self.navigation
        let target = self.target
        Button {
            switch target {
            case let .value(value?):
                navigation?.push(value: value)
            case .value(nil):
                break
            case let .destination(destination):
                navigation?.push(view: AnyView(destination))
            }
        } label: {
            HStack {
                label
                Spacer(minLength: 0)
                _ChevronShape(pointsDown: false)
                    .stroke(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 8, height: 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(_NavigationLinkButtonStyle())
    }
}

extension NavigationLink where Destination == Never {

    /// Creates a navigation link that presents the view corresponding to a value.
    public init<P: Hashable>(value: P?, @ViewBuilder label: () -> Label) {
        self.target = .value(value.map { AnyHashable($0) })
        self.label = label()
    }
}

extension NavigationLink where Label == Text, Destination == Never {

    /// Creates a navigation link that presents a destination view, with a
    /// text label generated from a title string.
    public init<P: Hashable>(_ titleKey: LocalizedStringKey, value: P?) {
        self.init(value: value) { Text(titleKey) }
    }

    /// Creates a navigation link that presents a destination view, with a
    /// text label generated from a title string.
    @_disfavoredOverload
    public init<S: StringProtocol, P: Hashable>(_ title: S, value: P?) {
        self.init(value: value) { Text(title) }
    }
}

extension NavigationLink where Label == Text {

    /// Creates a navigation link that presents a destination view, with a
    /// text label generated from a title string.
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder destination: () -> Destination) {
        self.init(destination: destination) { Text(titleKey) }
    }

    /// Creates a navigation link that presents a destination view, with a
    /// text label generated from a title string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, @ViewBuilder destination: () -> Destination) {
        self.init(destination: destination) { Text(title) }
    }
}

/// A link: its label in the primary color, dimmed while pressed.
private struct _NavigationLinkButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

// MARK: - Modifiers

/// Registers a destination for values of a type with the enclosing stack.
internal struct _NavigationDestinationModifier<D: Hashable>: ViewModifier, PrimitiveViewModifier {

    let destination: (D) -> AnyView

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        if let navigation = context.environment.navigationContext {
            let destination = self.destination
            navigation.destinations[ObjectIdentifier(D.self)] = { value in
                (value.base as? D).map(destination) ?? AnyView(EmptyView())
            }
        }
        return Resolution(children: [ChildView(key: 0, view: content)])
    }

    typealias Body = Never
}

/// Sets something on the screen's navigation bar.
internal struct _ScreenModifier: ViewModifier, PrimitiveViewModifier {

    /// Applies the setting, returning whether the bar needs updating.
    let apply: @MainActor (ScreenContext, ViewNode) -> Bool

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        if let screen = context.environment.screenContext, apply(screen, context.node) {
            screen.barNeedsUpdate()
        }
        return Resolution(children: [ChildView(key: 0, view: content)])
    }

    typealias Body = Never
}

extension View {

    /// Associates a destination view with a presented data type for use
    /// within a navigation stack.
    public func navigationDestination<D: Hashable, C: View>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View {
        modifier(_NavigationDestinationModifier<D> { AnyView(destination($0)) })
    }

    /// Configures the view's title for purposes of navigation.
    public func navigationTitle(_ title: Text) -> some View {
        let string = title.runs.map(\.string).joined()
        return modifier(_ScreenModifier { screen, _ in
            guard screen.title != string else { return false }
            screen.title = string
            return true
        })
    }

    /// Configures the view's title for purposes of navigation, using a
    /// localized string.
    public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View {
        navigationTitle(Text(titleKey))
    }

    /// Configures the view's title for purposes of navigation, using a string.
    @_disfavoredOverload
    public func navigationTitle<S: StringProtocol>(_ title: S) -> some View {
        navigationTitle(Text(title))
    }

    /// Hides the navigation bar back button for the view.
    public func navigationBarBackButtonHidden(_ hidesBackButton: Bool = true) -> some View {
        modifier(_ScreenModifier { screen, _ in
            guard screen.isBackButtonHidden != hidesBackButton else { return false }
            screen.isBackButtonHidden = hidesBackButton
            return true
        })
    }

    /// Populates the toolbar or navigation bar with the specified items.
    public func toolbar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let toolbar = AnyView(content())
        return modifier(_ScreenModifier { screen, node in
            // Its items' actions may change with every update.
            screen.toolbars[node.id] = toolbar
            return true
        })
    }

    /// Marks this view as searchable, which configures the display of a
    /// search field.
    public func searchable(text: Binding<String>, prompt: Text? = nil) -> some View {
        _Searchable(content: self, text: text, prompt: prompt)
    }

    /// Marks this view as searchable, with a localized prompt.
    public func searchable(text: Binding<String>, prompt: LocalizedStringKey) -> some View {
        searchable(text: text, prompt: Text(prompt))
    }
}

/// In a navigation stack, a search field in the bar; elsewhere, above the content.
internal struct _Searchable<Content: View>: View, PrimitiveView {

    let content: Content

    let text: Binding<String>

    let prompt: Text?

    func resolve(in context: ResolveContext) -> Resolution {
        if let screen = context.environment.screenContext {
            let changed = screen.search == nil
            screen.search = (text, prompt)
            if changed {
                screen.barNeedsUpdate()
            }
            return Resolution(children: [ChildView(key: "content", view: content)])
        }
        let view = VStack(spacing: 8) {
            TextField("Search", text: text, prompt: prompt ?? Text("Search"))
                .padding(.horizontal)
            content
        }
        return Resolution(children: [ChildView(key: "stacked", view: view)])
    }

    typealias Body = Never
}

// MARK: - Toolbar items

/// A model that represents an item which can be placed in the toolbar or
/// navigation bar.
public struct ToolbarItem<ID, Content: View>: View {

    internal let placement: ToolbarItemPlacement

    internal let content: Content

    public var body: some View {
        content
    }
}

extension ToolbarItem where ID == () {

    /// Creates a toolbar item with the specified placement and content.
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.content = content()
    }
}

/// A model that represents a group of toolbar items.
public struct ToolbarItemGroup<Content: View>: View {

    internal let placement: ToolbarItemPlacement

    internal let content: Content

    /// Creates a toolbar item group with a specified placement and content.
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.content = content()
    }

    public var body: some View {
        content
    }
}

/// A structure that defines the placement of a toolbar item.
public struct ToolbarItemPlacement: Sendable {

    internal enum Position {
        case leading
        case principal
        case trailing
    }

    internal let position: Position

    public static let automatic = ToolbarItemPlacement(position: .trailing)
    public static let principal = ToolbarItemPlacement(position: .principal)
    public static let navigation = ToolbarItemPlacement(position: .leading)
    public static let primaryAction = ToolbarItemPlacement(position: .trailing)
    public static let secondaryAction = ToolbarItemPlacement(position: .trailing)
    public static let status = ToolbarItemPlacement(position: .principal)
    public static let confirmationAction = ToolbarItemPlacement(position: .trailing)
    public static let cancellationAction = ToolbarItemPlacement(position: .leading)
    public static let destructiveAction = ToolbarItemPlacement(position: .trailing)
    public static let topBarLeading = ToolbarItemPlacement(position: .leading)
    public static let topBarTrailing = ToolbarItemPlacement(position: .trailing)
    public static let navigationBarLeading = ToolbarItemPlacement(position: .leading)
    public static let navigationBarTrailing = ToolbarItemPlacement(position: .trailing)
    public static let bottomBar = ToolbarItemPlacement(position: .trailing)
}

/// A toolbar item found in toolbar content.
internal struct ToolbarItemEntry {
    var placement: ToolbarItemPlacement
    var content: AnyView
}

@MainActor
internal protocol _ToolbarItemProtocol {
    var toolbarPlacement: ToolbarItemPlacement { get }
    var toolbarContent: AnyView { get }
}

extension ToolbarItem: _ToolbarItemProtocol {
    var toolbarPlacement: ToolbarItemPlacement { placement }
    var toolbarContent: AnyView { AnyView(content) }
}

extension ToolbarItemGroup: _ToolbarItemProtocol {
    var toolbarPlacement: ToolbarItemPlacement { placement }
    var toolbarContent: AnyView { AnyView(HStack(spacing: 12) { content }) }
}

/// The items in toolbar content, from its structure; plain views are
/// automatic items.
@MainActor
internal func toolbarItems(in view: any View) -> [ToolbarItemEntry] {
    switch view {
    case let item as any _ToolbarItemProtocol:
        return [ToolbarItemEntry(placement: item.toolbarPlacement, content: item.toolbarContent)]
    case let tuple as any _TupleContent:
        return tuple.tupleChildren.flatMap { toolbarItems(in: $0) }
    case let wrapper as any _StructuralWrapper:
        return wrapper.wrappedContent.map { toolbarItems(in: $0) } ?? []
    case is EmptyView:
        return []
    default:
        return [ToolbarItemEntry(placement: .automatic, content: AnyView(view))]
    }
}

// MARK: - NavigationSplitView

/// The visibility of the leading columns in a navigation split view.
public struct NavigationSplitViewVisibility: Equatable, Codable, Sendable {

    private enum Value: String, Codable {
        case detailOnly, doubleColumn, all, automatic
    }

    private let value: Value

    /// Hide the leading columns, showing only the detail.
    public static var detailOnly: NavigationSplitViewVisibility { .init(value: .detailOnly) }

    /// Show the content and detail columns of a three-column view, or the
    /// sidebar and detail of a two-column one.
    public static var doubleColumn: NavigationSplitViewVisibility { .init(value: .doubleColumn) }

    /// Show all the columns.
    public static var all: NavigationSplitViewVisibility { .init(value: .all) }

    /// The default for the platform: all the columns.
    public static var automatic: NavigationSplitViewVisibility { .init(value: .automatic) }

    /// Whether each column shows: the sidebar, the content if there is
    /// one, then the detail.
    func showsColumns(hasContent: Bool) -> [Bool] {
        switch value {
        case .detailOnly:
            hasContent ? [false, false, true] : [false, true]
        case .doubleColumn:
            hasContent ? [false, true, true] : [true, true]
        case .all, .automatic:
            hasContent ? [true, true, true] : [true, true]
        }
    }
}

/// A view that presents views in two or three columns, where selections in
/// leading columns control presentations in subsequent columns.
public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: View {

    internal let sidebar: Sidebar

    internal let content: Content?

    internal let detail: Detail

    internal let columnVisibility: Binding<NavigationSplitViewVisibility>?

    /// Creates a three-column navigation split view.
    public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {
        self.sidebar = sidebar()
        self.content = content()
        self.detail = detail()
        self.columnVisibility = nil
    }

    /// Creates a three-column navigation split view that shows the columns
    /// that `columnVisibility` says.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebar = sidebar()
        self.content = content()
        self.detail = detail()
        self.columnVisibility = columnVisibility
    }

    public var body: some View {
        _NavigationSplit(
            sidebar: AnyView(sidebar),
            content: content.map { AnyView($0) },
            detail: AnyView(detail),
            visibility: columnVisibility
        )
    }
}

extension NavigationSplitView where Content == EmptyView {

    /// Creates a two-column navigation split view.
    public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.sidebar = sidebar()
        self.content = nil
        self.detail = detail()
        self.columnVisibility = nil
    }

    /// Creates a two-column navigation split view that shows the columns
    /// that `columnVisibility` says.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebar = sidebar()
        self.content = nil
        self.detail = detail()
        self.columnVisibility = columnVisibility
    }
}

/// The width a column's views ask for.
internal struct SplitColumnWidth: Equatable {

    var min: CGFloat?

    var ideal: CGFloat

    var max: CGFloat?

    /// The ideal width, within the bounds.
    var width: CGFloat {
        var width = ideal
        if let max { width = Swift.min(width, max) }
        if let min { width = Swift.max(width, min) }
        return width
    }
}

/// The column width set by the views of a split view's column.
internal enum SplitColumnWidthKey: PreferenceKey {

    static var defaultValue: SplitColumnWidth? { nil }

    static func reduce(value: inout SplitColumnWidth?, nextValue: () -> SplitColumnWidth?) {
        if value == nil {
            value = nextValue()
        }
    }
}

extension View {

    /// Sets a fixed width for the column containing this view.
    public func navigationSplitViewColumnWidth(_ width: CGFloat) -> some View {
        preference(key: SplitColumnWidthKey.self, value: SplitColumnWidth(min: width, ideal: width, max: width))
    }

    /// Sets the width of the column containing this view: its ideal width,
    /// kept within `min` and `max`.
    public func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> some View {
        preference(key: SplitColumnWidthKey.self, value: SplitColumnWidth(min: min, ideal: ideal, max: max))
    }
}

/// Kinds of items that toolbars show by default.
public struct ToolbarDefaultItemKind: Sendable {

    internal enum Kind {
        case sidebarToggle
        case title
    }

    internal let kind: Kind

    /// The button that shows or hides a split view's sidebar.
    public static let sidebarToggle = ToolbarDefaultItemKind(kind: .sidebarToggle)

    /// The title of a window or navigation bar.
    public static let title = ToolbarDefaultItemKind(kind: .title)
}

/// Whether views of a split view's column removed the sidebar toggle.
internal enum SidebarToggleRemovedKey: PreferenceKey {

    static var defaultValue: Bool { false }

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {

    /// Removes a default item from the toolbar: the sidebar toggle of the
    /// split view this view is in.
    public func toolbar(removing defaultItemKind: ToolbarDefaultItemKind?) -> some View {
        preference(key: SidebarToggleRemovedKey.self, value: defaultItemKind?.kind == .sidebarToggle)
    }
}

/// The columns of a split view: a sidebar whose links show their
/// destinations in the detail column, and dividers that resize them.
private struct _NavigationSplit: View, PrimitiveView {

    let sidebar: AnyView

    let content: AnyView?

    let detail: AnyView

    let visibility: Binding<NavigationSplitViewVisibility>?

    func resolve(in context: ResolveContext) -> Resolution {
        let node = context.node
        let link: SplitLink
        if let existing = node.dynamicStorage["split"] as? SplitLink {
            link = existing
        } else {
            link = SplitLink()
            node.dynamicStorage["split"] = link
        }
        link.node = node
        link.hasContentColumn = content != nil
        if let visibility {
            link.currentVisibility = visibility.wrappedValue
            link.setVisibility = { visibility.wrappedValue = $0 }
        } else {
            link.currentVisibility = link.visibility
            link.setVisibility = { [weak link] value in
                link?.visibility = value
                link?.node?.invalidate()
            }
        }
        // A column's width comes from its views, through a preference, or
        // from dragging its divider.
        func column(_ key: String, _ view: some View, width: CGFloat?) -> some View {
            view
                .onPreferenceChange(SplitColumnWidthKey.self) { [weak node] value in
                    guard link.widths[key] != value else { return }
                    link.widths[key] = value
                    node?.invalidate()
                }
                .onPreferenceChange(SidebarToggleRemovedKey.self) { removes in
                    guard removes, !link.removesSidebarToggle else { return }
                    link.removesSidebarToggle = true
                    link.detail?.screens[0]?.barNeedsUpdate()
                }
                .frame(width: link.width(of: key, default: width))
        }
        let colorScheme = context.environment.colorScheme
        var children = [
            ChildView(
                key: "sidebar",
                view: column("sidebar", _NavigationStack(path: nil, root: sidebar, column: (link, false)), width: 240)
                    .background(Color.barBackground(colorScheme))
            ),
            ChildView(key: "sidebar-divider", view: _SplitDivider(link: link, column: "sidebar", defaultWidth: 240)),
        ]
        if let content {
            children.append(ChildView(key: "content", view: column("content", NavigationStack { content }, width: 280)))
            children.append(ChildView(key: "content-divider", view: _SplitDivider(link: link, column: "content", defaultWidth: 280)))
        }
        children.append(ChildView(
            key: "detail",
            view: column("detail", _NavigationStack(path: nil, root: detail, column: (link, true)), width: nil)
        ))
        let shows = link.currentVisibility.showsColumns(hasContent: content != nil)
        return Resolution(behavior: _SplitBehavior(shows: shows), children: children)
    }

    typealias Body = Never
}

/// A divider between columns, which resizes the column before it when
/// dragged.
private struct _SplitDivider: View {

    let link: SplitLink

    let column: String

    let defaultWidth: CGFloat

    @State private var startWidth: CGFloat?

    var body: some View {
        Color.separator
            .frame(width: 1)
            .frame(width: _SplitBehavior.dividerHitWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = startWidth ?? link.width(of: column, default: defaultWidth) ?? defaultWidth
                        if startWidth == nil { startWidth = start }
                        let range = link.range(of: column)
                        let width = min(max(start + value.translation.width, range.lowerBound), range.upperBound)
                        guard link.draggedWidths[column] != width else { return }
                        link.draggedWidths[column] = width
                        link.node?.invalidate()
                    }
                    .onEnded { _ in startWidth = nil }
            )
            .accessibilityHidden(true)
    }
}

/// Columns at their widths, the detail taking the rest, with 1-point
/// dividers between them. Each divider's view is wider than its line, to be
/// easy to drag, and centered on it. Hidden columns keep their views,
/// placed before the leading edge, and aren't drawn, nor their dividers.
private struct _SplitBehavior: NodeBehavior {

    /// The width of a divider's view, which takes drags.
    static let dividerHitWidth: CGFloat = 9

    /// Whether each column shows.
    let shows: [Bool]

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 800, height: 600))
    }

    /// The column of each child, and whether it's the column's divider.
    private func role(of index: Int, count: Int) -> (column: Int, isDivider: Bool) {
        index == count - 1 ? (index / 2, false) : (index / 2, index % 2 == 1)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        var x = bounds.minX
        let count = node.children.count
        let hit = Self.dividerHitWidth
        for index in 0..<count {
            guard let proxy = LayoutProxy.combining(node.layoutChildren(ofChildAt: index)) else { continue }
            let role = role(of: index, count: count)
            if index == count - 1 {
                proxy.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: max(bounds.maxX - x, 0), height: bounds.height))
            } else if role.isDivider {
                let proposal = ProposedViewSize(width: hit, height: bounds.height)
                guard shows(role.column) else {
                    proxy.place(at: CGPoint(x: bounds.minX - hit, y: bounds.minY), proposal: proposal)
                    continue
                }
                proxy.place(at: CGPoint(x: x + 0.5 - hit / 2, y: bounds.minY), proposal: proposal)
                x += 1
            } else {
                let width = proxy.size(in: ProposedViewSize(width: nil, height: bounds.height)).width
                let proposal = ProposedViewSize(width: width, height: bounds.height)
                guard shows(role.column) else {
                    proxy.place(at: CGPoint(x: bounds.minX - width, y: bounds.minY), proposal: proposal)
                    continue
                }
                proxy.place(at: CGPoint(x: x, y: bounds.minY), proposal: proposal)
                x += width
            }
        }
    }

    private func shows(_ column: Int) -> Bool {
        shows.indices.contains(column) ? shows[column] : true
    }

    /// Shown columns, then their dividers in front.
    func displayOrder(of children: [ViewNode]) -> [ViewNode] {
        let roles = children.indices.map { role(of: $0, count: children.count) }
        let columns = children.indices.filter { !roles[$0].isDivider && shows(roles[$0].column) }
        let dividers = children.indices.filter { roles[$0].isDivider && shows(roles[$0].column) }
        return (columns + dividers).map { children[$0] }
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        nil
    }
}
