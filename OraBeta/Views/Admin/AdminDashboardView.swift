//
//  AdminDashboardView.swift
//  OraBeta
//
//  Admin dashboard using OraBetaAdmin SDK - strictly SDK-based, no additional functionality
//

import SwiftUI
import FirebaseAuth
import OraBetaAdmin
import Combine

struct AdminDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = AdminDashboardViewModel()
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let error = viewModel.error {
                    Section {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                        Button("Retry") {
                            Task {
                                await viewModel.initialize(authViewModel: authViewModel)
                            }
                        }
                    }
                } else {
                    analyticsSection
                    moderationSection
                    userManagementSection
                    interestSyncSection
                    webDashboardSection
                    adminInfoSection
                }
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.initialize(authViewModel: authViewModel)
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    private var analyticsSection: some View {
        Section(header: Text("Analytics")) {
            if let analytics = viewModel.analytics {
                HStack {
                    Text("Total Users")
                    Spacer()
                    Text("\(analytics.users.total)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Total Posts")
                    Spacer()
                    Text("\(analytics.posts.total)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Pending Moderation")
                    Spacer()
                    Text("\(analytics.posts.pending)")
                        .foregroundColor(.orange)
                }
                HStack {
                    Text("Flagged Posts")
                    Spacer()
                    Text("\(analytics.posts.flagged)")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var moderationSection: some View {
        Section(header: Text("Moderation")) {
            if let queue = viewModel.moderationQueue {
                HStack {
                    Text("Pending Posts")
                    Spacer()
                    Text("\(queue.count)")
                        .foregroundColor(.orange)
                }
            }
            
            Link(destination: getModerationDeepLink()) {
                HStack {
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(.blue)
                    Text("Open Moderation Dashboard")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var userManagementSection: some View {
        Section(header: Text("User Management")) {
            if let users = viewModel.users {
                HStack {
                    Text("Total Users")
                    Spacer()
                    Text("\(users.total)")
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://dashboard.ora.riceboxai.com/users")!) {
                HStack {
                    Image(systemName: "person.3")
                        .foregroundColor(.blue)
                    Text("Open User Management")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var interestSyncSection: some View {
        Section(header: Text("Interest Management")) {
            Button(action: {
                Task {
                    await viewModel.syncInterestCounts()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                    Text("Sync Interest Post Counts")
                    Spacer()
                    if viewModel.isSyncing {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isSyncing)
            
            if let syncResult = viewModel.syncResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("✅ Sync Complete")
                            .font(.headline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Processed:")
                        Spacer()
                        Text("\(syncResult.processed)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Updated:")
                        Spacer()
                        Text("\(syncResult.updated)")
                            .foregroundColor(.blue)
                    }
                    
                    if syncResult.errors.count > 0 {
                        HStack {
                            Text("Errors:")
                            Spacer()
                            Text("\(syncResult.errors.count)")
                                .foregroundColor(.red)
                        }
                    }
                }
                .font(.caption)
                .padding(.vertical, 4)
            }
            
            if let syncError = viewModel.syncError {
                Text(syncError)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var webDashboardSection: some View {
        Section(header: Text("Web Dashboard")) {
            Link(destination: getDashboardDeepLink()) {
                HStack {
                    Image(systemName: "safari")
                        .foregroundColor(.blue)
                    Text("Open Full Dashboard")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: getContentDeepLink()) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.blue)
                    Text("Content Management")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: getAnalyticsDeepLink()) {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.blue)
                    Text("Analytics")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: getSettingsDeepLink()) {
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundColor(.blue)
                    Text("System Settings")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Deep Link Helpers
    
    private func getDashboardDeepLink() -> URL {
        return URL(string: "https://dashboard.ora.riceboxai.com")!
    }
    
    private func getUserDeepLink(userId: String) -> URL {
        return URL(string: "https://dashboard.ora.riceboxai.com/users/\(userId)")!
    }
    
    private func getPostDeepLink(postId: String) -> URL {
        return URL(string: "https://dashboard.ora.riceboxai.com/content?post=\(postId)")!
    }
    
    private func getModerationDeepLink() -> URL {
        return URL(string: "https://dashboard.ora.riceboxai.com/moderation")!
    }
    
    private func getContentDeepLink() -> URL {
        return URL(string: "https://dashboard.ora.riceboxai.com/content")!
    }
    
    private func getAnalyticsDeepLink() -> URL {
        return URL(string: "https://dashboard.ora.riceboxai.com/analytics")!
    }
    
    private func getSettingsDeepLink() -> URL {
        return URL(string: "https://dashboard.ora.riceboxai.com/settings")!
    }
    
    private var adminInfoSection: some View {
        Section(header: Text("Admin Information")) {
            HStack {
                Text("Admin User")
                Spacer()
                Text(viewModel.currentAdmin?.email ?? authViewModel.currentUser?.email ?? "Unknown")
                    .foregroundColor(.secondary)
            }
            
            if let role = viewModel.currentAdmin?.role {
                HStack {
                    Text("Role")
                    Spacer()
                    Text(role.capitalized)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

@MainActor
class AdminDashboardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var analytics: AnalyticsResponse?
    @Published var moderationQueue: ModerationQueueResponse?
    @Published var users: UsersResponse?
    @Published var currentAdmin: AdminUser?
    @Published var isSyncing = false
    @Published var syncResult: InterestSyncService.SyncResult?
    @Published var syncError: String?
    
    private var client: AdminClient?
    
    // MARK: - SDK Methods Only
    
    func initialize(authViewModel: AuthViewModel) async {
        isLoading = true
        error = nil
        
        do {
            // Get Firebase token
            guard let user = Auth.auth().currentUser else {
                error = "Not authenticated"
                isLoading = false
                return
            }
            
            let firebaseToken = try await user.getIDToken()
            
            // Initialize SDK client with environment-specific base URL
            let config = AdminConfig(baseURL: Config.adminAPIBaseURL)
            let adminClient = AdminClient(config: config)
            
            // Login with SDK
            let loginResponse = try await adminClient.login(firebaseToken: firebaseToken)
            self.currentAdmin = loginResponse.admin
            
            // Store client for future requests
            self.client = adminClient
            
            // Load initial data using SDK methods only
            await refresh()
            
        } catch {
            self.error = error.localizedDescription
            print("Admin SDK initialization error: \(error)")
            if let adminError = error as? AdminError {
                print("Admin Error Details: \(adminError.localizedDescription)")
            }
        }
        
        isLoading = false
    }
    
    func refresh() async {
        guard let client = client else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Use SDK methods only - no custom logic
            async let analyticsTask = client.getAnalytics(period: "30d")
            async let moderationTask = client.getModerationQueue(status: "pending")
            async let usersTask = client.getUsers(limit: 1, offset: 0)
            
            let (analytics, moderation, users) = try await (analyticsTask, moderationTask, usersTask)
            
            self.analytics = analytics
            self.moderationQueue = moderation
            self.users = users
            
        } catch {
            self.error = error.localizedDescription
            print("Admin refresh error: \(error)")
            if let adminError = error as? AdminError {
                print("Admin Error Details: \(adminError.localizedDescription)")
            }
        }
        
        isLoading = false
    }
    
    func syncInterestCounts() async {
        isSyncing = true
        syncError = nil
        syncResult = nil
        
        do {
            let result = try await InterestSyncService.shared.syncAllInterestPostCounts()
            syncResult = result
            Logger.log("✅ Interest sync completed: \(result.updated) interests updated", service: "AdminDashboard")
        } catch {
            syncError = error.localizedDescription
            Logger.error("❌ Interest sync failed: \(error.localizedDescription)", service: "AdminDashboard")
        }
        
        isSyncing = false
    }
}

#Preview {
    AdminDashboardView()
        .environmentObject(AuthViewModel())
}
