// Created on 2026-02-26
// Copyright © 2026 OrderedBytes.  All rights reserved.

import SwiftUI


// MARK: - HIDManagerView

/// A view for opening or closing HID manager instances.
internal struct HIDManagerView: View {
	/// Constructs an instance with a binding to the current HID Manager.
	///
	/// - Parameter hidManager: A binding to the current HID manager.
	internal init(hidManager: Binding<IOHIDManager?>) {
		self._hidManager = hidManager
	}
	
	internal var body: some View {
		VStack(alignment: .leading) {
			Text("HIDManagerView.Heading")
				.bold()
			
			Button(
				self.hidManager == nil ? "HIDManagerView.ButtonTitle.Open" : "HIDManagerView.ButtonTitle.Close",
				action: {
					if self.hidManager == nil {
						self.hidManager = IOHIDManager.create()
					} else {
						self.hidManager = nil
					}
				}
			)
			.padding(.leading, 10)
			.fixedSize()
		}
	}
	
	/// A binding to the current HID manager.
	@Binding private var hidManager: IOHIDManager?
}


// MARK: - Previews

#Preview {
	@Previewable @State var hidManager: IOHIDManager?
	HIDManagerView(hidManager: $hidManager)
		.controlSize(.small)
		.padding()
}
