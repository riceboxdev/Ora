//
//  FeedConstants.swift
//  OraBeta
//
//  Created for feed refresh notifications
//

import Foundation

extension Foundation.Notification.Name {
    /// Notification posted when the home feed should be refreshed
    /// Typically triggered after follow/unfollow actions
    static let feedShouldRefresh = Foundation.Notification.Name("feedShouldRefresh")
}

