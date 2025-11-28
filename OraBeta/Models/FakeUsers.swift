//
//  FakeUsers.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation

/// Fake users for previewing stories in development
struct FakeUsers {
    static let users: [UserProfile] = [
        UserProfile(
            id: "user1",
            email: "alex.johnson@example.com",
            username: "alexj",
            bio: "Tech enthusiast and coffee lover ☕",
            profilePhotoUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762830367/users/ChXrUkIGqsS1TMVi6avPKAhIlxn1/jxotu1llhwxn2swukk1l.jpg",
            followerCount: 1247,
            followingCount: 892
        ),
        UserProfile(
            id: "user2",
            email: "sara.wilson@example.com",
            username: "saraw",
            bio: "Artist | Nature lover | Always creating ✨",
            profilePhotoUrl: "https://imagedelivery.net/-U9fBlv98S0Bl-wUpX9XJw/35c8ea66-ec66-471e-33d1-5f451c112200/public",
            followerCount: 2156,
            followingCount: 743
        ),
        UserProfile(
            id: "user3",
            email: "mike.chen@example.com",
            username: "mikechen",
            bio: "Photographer | Foodie | Adventure seeker 🏔️",
            profilePhotoUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762896256/users/xLX0DReWAPQad0Hl6H1hp90fnjA3/wvfp1i1xscjrow4hvhut.jpg",
            followerCount: 1892,
            followingCount: 456
        ),
        UserProfile(
            id: "user4",
            email: "lisa.rodriguez@example.com",
            username: "lisar",
            bio: "Designer | Minimalist | Yoga instructor 🧘‍♀️",
            profilePhotoUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762902205/users/0bULA5bM4OhI71GC5V0JhGiRvGG3/oklbrqbrdmgizt3tos5d.jpg",
            followerCount: 3241,
            followingCount: 1123
        )
    ]
}
