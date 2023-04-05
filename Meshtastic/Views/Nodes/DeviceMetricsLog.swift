//
//  DeviceMetricsLog.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 7/7/22.
//
import SwiftUI
import Charts

struct DeviceMetricsLog: View {
	
	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var bleManager: BLEManager
	
	@State private var isPresentingClearLogConfirm: Bool = false
	@State var isExporting = false
	@State var exportString = ""
	var node: NodeInfoEntity
	
	var body: some View {
		
		let oneDayAgo = Calendar.current.date(byAdding: .hour, value: -12, to: Date())
		let deviceMetrics = node.telemetries?.filtered(using: NSPredicate(format: "metricsType == 0")).reversed() as? [TelemetryEntity] ?? []
		let chartData = deviceMetrics
			.filter { $0.time != nil && $0.time! >= oneDayAgo! }
			.sorted { $0.time! < $1.time! }
		
		NavigationStack {
			
			if chartData.count > 0 {
				GroupBox(label: Label("8 Hour Trend - \(deviceMetrics.count) Readings Total", systemImage: "chart.xyaxis.line")) {
					
					Chart(chartData, id: \.self) {
						
						LineMark(
							x: .value("Hour", $0.time!.formattedDate(format: "ha")),
							y: .value("Value", $0.batteryLevel)
						)
						.interpolationMethod(.linear)
						.foregroundStyle(.blue)
						PointMark(
							x: .value("Hour", $0.time!.formattedDate(format: "ha")),
							y: .value("Value", $0.batteryLevel)
						)
						.foregroundStyle(.blue)
						PointMark(
							x: .value("Hour", $0.time!.formattedDate(format: "ha")),
							y: .value("Value", $0.channelUtilization)
						)
						.foregroundStyle(.green)
						PointMark(
							x: .value("Hour", $0.time!.formattedDate(format: "ha")),
							y: .value("Value", $0.airUtilTx)
						)
						.foregroundStyle(.orange)
					}
					.chartForegroundStyleScale([
						"Battery Level" : .blue,
						"Channel Utilization": .green,
						"Airtime": .orange
					])
					.chartLegend(position: .automatic, alignment: .bottom)
				}
				.frame(height: 225)
			}
			let localeDateFormat = DateFormatter.dateFormat(fromTemplate: "yyMMddjmma", options: 0, locale: Locale.current)
			let dateFormatString = (localeDateFormat ?? "MM/dd/YY j:mma").replacingOccurrences(of: ",", with: "")
			if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
				
				// Add a table for mac and ipad
				//Table(Array(deviceMetrics),id: \.self) {
				Table(deviceMetrics) {
					TableColumn("battery.level") { dm in
						if dm.batteryLevel > 100 {
							Text("Powered")
						} else {
							Text("\(String(dm.batteryLevel))%")
						}
					}
					TableColumn("voltage") { dm in
						Text("\(String(format: "%.2f", dm.voltage))")
					}
					TableColumn("channel.utilization") { dm in
						Text(String(format: "%.2f", dm.channelUtilization))
					}
					TableColumn("airtime") { dm in
						Text("\(String(format: "%.2f", dm.airUtilTx))%")
					}
					TableColumn("timestamp") { dm in
						Text(dm.time?.formattedDate(format: dateFormatString) ?? NSLocalizedString("unknown.age", comment: ""))
					}
				}
			} else {
				ScrollView {
					let columns = [
						GridItem(.flexible(minimum: 30, maximum: 60), spacing: 0.1),
						GridItem(.flexible(minimum: 30, maximum: 60), spacing: 0.1),
						GridItem(.flexible(minimum: 30, maximum: 70), spacing: 0.1),
						GridItem(.flexible(minimum: 30, maximum: 65), spacing: 0.1),
						GridItem(spacing: 0)
					]
					LazyVGrid(columns: columns, alignment: .leading, spacing: 1) {
						GridRow {
							Text("Batt")
								.font(.caption)
								.fontWeight(.bold)
							Text("Volt")
								.font(.caption)
								.fontWeight(.bold)
							Text("ChUtil")
								.font(.caption)
								.fontWeight(.bold)
							Text("AirTm")
								.font(.caption)
								.fontWeight(.bold)
							Text("timestamp")
								.font(.caption)
								.fontWeight(.bold)
						}
						ForEach(deviceMetrics) { dm in
							GridRow {
								if dm.batteryLevel > 100 {
									Text("PWD")
										.font(.caption)
								} else {
									Text("\(String(dm.batteryLevel))%")
										.font(.caption)
								}
								Text(String(dm.voltage))
									.font(.caption)
								Text("\(String(format: "%.2f", dm.channelUtilization))%")
									.font(.caption)
								Text("\(String(format: "%.2f", dm.airUtilTx))%")
									.font(.caption)
								Text(dm.time?.formattedDate(format: dateFormatString) ?? "Unknown time")
									.font(.caption2)
							}
						}
					}
					.padding(.leading, 15)
					.padding(.trailing, 5)
				}
			}
		}
		HStack {
			Button(role: .destructive) {
				isPresentingClearLogConfirm = true
			} label: {
				Label("clear.log", systemImage: "trash.fill")
			}
			.buttonStyle(.bordered)
			.buttonBorderShape(.capsule)
			.controlSize(.large)
			.padding()
			.confirmationDialog(
				"are.you.sure",
				isPresented: $isPresentingClearLogConfirm,
				titleVisibility: .visible
			) {
				Button("device.metrics.delete", role: .destructive) {
					if clearTelemetry(destNum: node.num, metricsType: 0, context: context) {
						print("Cleared Device Metrics for \(node.num)")
					} else {
						print("Clear Device Metrics Log Failed")
					}
				}
			}
			Button {
				exportString = telemetryToCsvFile(telemetry: node.telemetries!.array as? [TelemetryEntity] ?? [], metricsType: 0)
				isExporting = true
			} label: {
				Label("save", systemImage: "square.and.arrow.down")
			}
			.buttonStyle(.bordered)
			.buttonBorderShape(.capsule)
			.controlSize(.large)
			.padding()
		}
		.navigationTitle("device.metrics.log")
		.navigationBarTitleDisplayMode(.inline)
		.navigationBarItems(trailing:
			ZStack {
				ConnectedDevice(bluetoothOn: bleManager.isSwitchedOn, deviceConnected: bleManager.connectedPeripheral != nil, name: (bleManager.connectedPeripheral != nil) ? bleManager.connectedPeripheral.shortName : "????")
		})
		.onAppear {
			self.bleManager.context = context
		}
		.fileExporter(
			isPresented: $isExporting,
			document: CsvDocument(emptyCsv: exportString),
			contentType: .commaSeparatedText,
			defaultFilename: String("\(node.user?.longName ?? "Node") \(NSLocalizedString("device.metrics.log", comment: "Device Metrics Log"))"),
			onCompletion: { result in
				if case .success = result {
					print("Device metrics log download succeeded.")
					self.isExporting = false
				} else {
					print("Device metrics log download failed: \(result).")
				}
			}
		)
	}
}
