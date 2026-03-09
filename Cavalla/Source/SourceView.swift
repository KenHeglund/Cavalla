// Created on 2026-02-25
// Copyright © 2026 OrderedBytes.  All rights reserved.

import IOKit.hid
import OSLog
import SwiftUI


// MARK: - SourceView

/// A view that displays the HID sources that are currently available.
internal struct SourceView: View {
	/// Constructs an instance with a model.
	///
	/// - Parameter model: The main model to use.
	internal init(model: CavallaModel) {
		self.sourceModel = model
	}
	
	internal var body: some View {
		@Bindable var model = self.sourceModel
		
		VStack(alignment: .leading, spacing: 20) {
			HIDManagerView(hidManager: $model.hidManager)
			HIDDevicesView(devices: $model.deviceModels, selection: $model.selectedDeviceModel)
			HIDElementsView(elements: model.selectedDeviceModel?.elements)
		}
		.controlSize(.small)
	}
	
	
	// MARK: - Private
	
	/// The main model to use.
	private let sourceModel: CavallaModel
}


// MARK: - Previews

#Preview {
	SourceView(model: CavallaModel())
		.padding()
		.frame(width: 400)
}
