// Created on 2026-03-01
// Copyright © 2026 OrderedBytes.  All rights reserved.

import SwiftUI


// MARK: - HIDElementsView

/// A view that displays a filterable list of HID elements.
internal struct HIDElementsView: View {
	/// Constructs an instance from an array of elements.
	///
	/// - Parameter elements: The elements to display.
	init(elements: [HIDElementModel]?) {
		self.elements = elements ?? []
	}
	
	internal var body: some View {
		VStack(alignment: .leading) {
			Text("HIDElementsView.Title")
				.bold()
			
			Table(
				of: HIDElementModel.self,
				selection: self.$tableSelection,
				columns: {
					TableColumn("HIDElementsView.TableColumnTitle.Enabled") { element in
						@Bindable var element = element
						Toggle("", isOn: $element.enabled)
							.labelsHidden()
							.disabled(!element.canEnable)
							.padding(.trailing, 10)
							.frame(maxWidth: .infinity, alignment: .center)
							.opacity(element.canEnable ? 1.0 : 0.25)
					}
					.width(52)
					
					TableColumn("HIDElementsView.TableColumnTitle.Cookie") { element in
						Text(String(element.cookie))
							.foregroundStyle(element.canEnable ? .primary : .tertiary)
							.padding(.trailing, 10)
							.frame(maxWidth: .infinity, alignment: .center)
					}
					.width(44)
					
					TableColumn("HIDElementsView.TableColumnTitle.Name") { element in
						Text(element.nameString)
							.foregroundStyle(element.canEnable ? .primary : .tertiary)
					}
					.width(min: 44, max: 240)
					
					TableColumn("HIDElementsView.TableColumnTitle.Usage") { element in
						Text(element.usageString)
							.foregroundStyle(element.canEnable ? .primary : .tertiary)
					}
					.width(88)
					
					TableColumn("HIDElementsView.TableColumnTitle.Size") { element in
						Text(element.sizeString)
							.foregroundStyle(element.canEnable ? .primary : .tertiary)
					}
					.width(40)
				},
				rows: {
					ForEach(self.filteredElements) { element in
						TableRow(element)
							.selectionDisabled(!element.canEnable)
					}
				}
			)
			.tableStyle(.bordered)
			.padding(.horizontal, 10)
			.onKeyPress(.space) {
				self.handleSpaceKeyInTable()
				return .handled
			}
			
			TextField("HIDElementsView.Filter.Prompt", text: self.$filterString)
				.textFieldStyle(.roundedBorder)
				.disabled(self.elements.isEmpty)
				.padding(2)
				.padding(.leading, 10)
				.opacity(self.elements.isEmpty ? 0.25 : 1.0)
		}
		.onAppear {
			self.filteredElements = self.elements
		}
		.onChange(of: self.elements, { oldValue, newValue in
			self.filteredElements = newValue
			self.filterString = ""
			self.tableSelection = []
		})
		.onChange(of: self.filterString, { _, newValue in
			self.updateFilteredElements(using: newValue)
		})
	}
	
	/// The complete collection of elements to display.
	private let elements: [HIDElementModel]
	
	/// Text that is used to filter elements.
	@State private var filterString = ""
	
	/// A subset of `elements` that match `filterString`.
	@State private var filteredElements: [HIDElementModel] = []
	
	/// The IDs of the currently selected elements.
	@State private var tableSelection: Set<HIDElementModel.ID> = []
	
	/// Updates the filtered elements based on the given filter string.
	///
	/// - Parameter filter: A string to compare to element names.
	private func updateFilteredElements(using filter: String) {
		let filter = filter.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !filter.isEmpty else {
			if self.filteredElements.count != self.elements.count {
				self.filteredElements = self.elements
			}
			return
		}
		
		self.filteredElements = self.elements.filter({
			$0.nameString.localizedCaseInsensitiveContains(filter)
		})
	}
	
	/// Responds to the Space key.
	///
	/// The Space key toggles the enabled/disabled state of selected HID elements.
	///
	/// If multiple elements are selected, and one or more of them are disabled,
	/// then all elements that are currently disabled will be enabled.  Any
	/// selected elements that are already enabled will remain enabled.
	///
	/// If the selected elements are either all enabled or all disabled, then the
	/// enabled/disabled state of all elements are toggled.
	private func handleSpaceKeyInTable() {
		let tableSelection = self.tableSelection
		
		let enabledCookies = Array(self.filteredElements.lazy.filter(\.enabled).compactMap(\.id))
		let isDisabledElementSelected = tableSelection.contains(where: { !enabledCookies.contains($0) })
		
		for element in self.filteredElements where tableSelection.contains(element.id) {
			if isDisabledElementSelected {
				// A disabled element is selected.  Enable all elements that are not
				// already enabled.
				if !enabledCookies.contains(element.id) {
					element.enabled = true
				}
			} else {
				// All selected elements are enabled.  Disable all selected elements.
				if enabledCookies.contains(element.id) {
					element.enabled = false
				}
			}
		}
	}
}


// MARK: - Previews

#Preview {
	HIDElementsView(elements: [])
		.controlSize(.small)
		.frame(width: 300)
		.padding()
}
