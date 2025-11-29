//
//  AppTheme.swift
//  Electric Slideshow
//
//  Shared styling helpers for the app's UI
//

import SwiftUI

enum AppTheme {
    enum Sidebar {
        // Layout
        static let horizontalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let cornerRadius: CGFloat = 8

        // Colors
        static let panelBackground = Color(nsColor: .controlBackgroundColor)
        static let cardBackground = Color.primary.opacity(0.04)
        static let hoverBackground = Color.primary.opacity(0.05)
    }
}

// MARK: - View modifiers

private struct SidebarSectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(1)
    }
}

private struct SidebarCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Sidebar.cornerRadius)
                    .fill(AppTheme.Sidebar.cardBackground)
            )
    }
}

private struct SidebarHoverRowModifier: ViewModifier {
    let isHovering: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Sidebar.cornerRadius)
                    .fill(isHovering ? AppTheme.Sidebar.hoverBackground : .clear)
            )
    }
}

// MARK: - View extensions

extension View {
    func sidebarSectionHeaderStyle() -> some View {
        modifier(SidebarSectionHeaderModifier())
    }

    func sidebarCardStyle() -> some View {
        modifier(SidebarCardModifier())
    }

    func sidebarHoverRow(isHovering: Bool) -> some View {
        modifier(SidebarHoverRowModifier(isHovering: isHovering))
    }
}
