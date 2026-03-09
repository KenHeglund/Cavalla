// Created on 2026-03-01
// Copyright © 2026 OrderedBytes.  All rights reserved.

import SwiftUI


// MARK: - HIDDevicesView

/// A view that displays the currently available HID devices, and details of the
/// currently selected device.
internal struct HIDDevicesView: View {
	/// Constructs an instance from bindings to the currently available devices
	/// and the currently selected device.
	///
	/// - Parameters:
	///   - devices: A binding to the currently available device models.
	///   - selection: A binding to the currently selected device model.
	init(
		devices: Binding<[HIDDeviceModel]>,
		selection: Binding<HIDDeviceModel?>
	) {
		self._deviceModels = devices
		self._selectedDeviceModel = selection
	}
	
	internal var body: some View {
		VStack(alignment: .leading) {
			Text("HIDDevicesView.Heading")
				.bold()
			
			Picker("", selection: self.$selectedServiceObject, content: {
				ForEach(self.devicePickerElements, id: \.1) { title, id in
					Text(title)
						.tag(id)
				}
			})
			.labelsHidden()
			.disabled(self.deviceModels.isEmpty)
			.fixedSize(horizontal: self.deviceModels.isEmpty, vertical: false)
			.padding(.leading, 10)
			
			let spacing: CGFloat = 8
			let device = self.deviceModels.first(where: {
				$0.serviceObject == self.selectedServiceObject
			})
			
			HStack(spacing: spacing) {
				VStack(alignment: .trailing, spacing: spacing) {
					Text("HIDDevicesView.Label.VendorID")
					Text("HIDDevicesView.Label.ProductID")
					Text("HIDDevicesView.Label.Version")
					Text("HIDDevicesView.Label.Elements")
				}
				
				VStack(alignment: .leading, spacing: spacing) {
					Text(device?.vendorIDString ?? "")
					Text(device?.productIDString ?? "")
					Text(device?.versionString ?? "")
					Text(device.map({ "\($0.elements.count)" }) ?? "")
				}
			}
			.lineLimit(1)
			.fixedSize(horizontal: true, vertical: false)
			.foregroundStyle(.secondary)
			.padding(.top, 2)
			.padding(.leading, 20)
		}
		.onChange(of: self.deviceModels, { oldValue, newValue in
			if self.selectedServiceObject == 0, !newValue.isEmpty {
				self.selectedServiceObject = newValue.first?.serviceObject ?? 0
			} else if newValue.isEmpty {
				self.selectedServiceObject = 0
			}
		})
		.onChange(of: self.selectedServiceObject, { oldValue, newValue in
			self.selectedDeviceModel = self.deviceModels.first(where: { $0.serviceObject == newValue })
		})
	}
	
	/// A binding to the currently available device models.
	@Binding private var deviceModels: [HIDDeviceModel]
	
	/// A binding to the currently selected device model.
	@Binding private var selectedDeviceModel: HIDDeviceModel?
	
	/// The service object associated with the currently selected device.
	@State private var selectedServiceObject: UInt32 = 0
	
	/// An array of tuples repsenting entries in the popup that allows the user to
	/// select a device.  The first member of each tuple is the name of the device
	/// that appears in the popup menu.  The second member of each tuple is the
	/// service object associated with the device.
	private var devicePickerElements: [(String, UInt32)] {
		let elements = self.deviceModels.map({ ($0.longProductName, $0.serviceObject) })
		if !elements.isEmpty {
			return elements
		} else {
			return [(String(localized: "HIDDevicesView.Label.NoDevices"), 0)]
		}
	}
}


// MARK: - Previews

#Preview {
	HIDDevicesView(devices: .constant([]), selection: .constant(nil))
		.controlSize(.small)
		.padding()
}
