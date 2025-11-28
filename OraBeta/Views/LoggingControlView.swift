//
//  LoggingControlView.swift
//  OraBeta
//
//  View for controlling logging services
//

import SwiftUI

struct LoggingControlView: View {
    @State private var services: [String: Bool] = [:]
    @State private var searchText = ""
    
    var filteredServices: [String] {
        let allServices = Array(services.keys).sorted()
        if searchText.isEmpty {
            return allServices
        }
        return allServices.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search services...", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Service list
                List {
                    if filteredServices.isEmpty {
                        Text("No services found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(filteredServices, id: \.self) { serviceName in
                            ServiceToggleRow(
                                serviceName: serviceName,
                                isEnabled: Binding(
                                    get: { services[serviceName] ?? true },
                                    set: { newValue in
                                        services[serviceName] = newValue
                                        if newValue {
                                            LoggingServiceRegistry.shared.enable(serviceName: serviceName)
                                        } else {
                                            LoggingServiceRegistry.shared.disable(serviceName: serviceName)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }
                .listStyle(PlainListStyle())
                
                // Control buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: {
                            LoggingServiceRegistry.shared.enableAll()
                            loadServices()
                        }) {
                            Text("Enable All")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            LoggingServiceRegistry.shared.disableAll()
                            loadServices()
                        }) {
                            Text("Disable All")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    Button(action: {
                        LoggingServiceRegistry.shared.resetToDefaults()
                        loadServices()
                    }) {
                        Text("Reset to Defaults")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Logging Control")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadServices()
            }
        }
    }
    
    private func loadServices() {
        services = LoggingServiceRegistry.shared.getAllServicesWithState()
    }
}

struct ServiceToggleRow: View {
    let serviceName: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(serviceName)
                    .font(.headline)
                
                // Show current log level if available
                let logLevel = LoggingConfig.logLevel(for: serviceName)
                Text("Level: \(logLevel.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// Helper extension for easy access
extension View {
    /// Add a toolbar button to open logging control
    func loggingControlToolbar() -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: LoggingControlView()) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// Preview
struct LoggingControlView_Previews: PreviewProvider {
    static var previews: some View {
        LoggingControlView()
    }
}






