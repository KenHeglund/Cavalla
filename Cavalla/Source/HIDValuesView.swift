// Created on 2026-03-04
// Copyright © 2026 OrderedBytes.  All rights reserved.

import SwiftUI


// MARK: - HIDValuesView

/// A view that displays the text describing recently observed HID events.
internal struct HIDValuesView: View {
	/// Constructs an instance with a binding to text storage.
	///
	/// - Parameter eventText: A binding to text to display.
	internal init(eventText: Binding<String>) {
		self._eventText = eventText
	}
	
	internal var body: some View {
		VStack(alignment: .leading) {
			Text("HIDValuesView.Title")
				.bold()
			
			ScrollViewReader { proxy in
				ScrollView {
					TextEditor(text: self.$eventText)
						.disabled(true)
						.font(.custom("Courier New", size: 12))
						.foregroundStyle(.secondary)
						.id("editor")
				}
				.padding(.vertical, 8)
				.padding(.horizontal, 2)
				.border(.tertiary)
				.padding(.leading, 10)
				.onChange(of: self.eventText, {
					proxy.scrollTo("editor", anchor: .bottom)
				})
			}
			
			HStack {
				Spacer()
				Button(
					"HIDValuesView.ButtonTitle.Clear",
					action: {
						self.eventText = ""
					}
				)
				.disabled(self.eventText.isEmpty)
			}
		}
		.controlSize(.small)
	}
	
	/// A binding to the text to display.
	@Binding private var eventText: String
}


// MARK: - Previews

#Preview {
	@Previewable @State var eventText: String = ""
	HIDValuesView(eventText: $eventText)
		.frame(width: 200)
		.padding()
}
