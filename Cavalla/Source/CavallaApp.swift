// Created on 2026-03-01
// Copyright © 2026 OrderedBytes.  All rights reserved.

import SwiftUI


// MARK: - CavallaApp

@main
internal struct CavallaApp: App {
	internal var body: some Scene {
		WindowGroup {
			self.windowContent
		}
	}
	
	
	// MARK: - Private
	
	/// The model of the main window of the application.
	@State private var sourceModel = CavallaModel()
	
	/// The content of the main window.
	@ViewBuilder
	fileprivate var windowContent: some View {
		HSplitView {
			SourceView(model: self.sourceModel)
				.padding(.trailing, 10)
			
			@Bindable var model = self.sourceModel
			
			HIDValuesView(eventText: $model.eventText)
				.padding(.leading, 10)
				.frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
		}
		.padding()
	}
}


// MARK: - Previews

#Preview {
	CavallaApp().windowContent
}
