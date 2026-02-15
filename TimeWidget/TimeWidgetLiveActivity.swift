//
//  TimeWidgetLiveActivity.swift
//  TimeWidget
//
//  Created by Alireza on 14.02.26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TimeWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TimeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimeWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TimeWidgetAttributes {
    fileprivate static var preview: TimeWidgetAttributes {
        TimeWidgetAttributes(name: "World")
    }
}

extension TimeWidgetAttributes.ContentState {
    fileprivate static var smiley: TimeWidgetAttributes.ContentState {
        TimeWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TimeWidgetAttributes.ContentState {
         TimeWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TimeWidgetAttributes.preview) {
   TimeWidgetLiveActivity()
} contentStates: {
    TimeWidgetAttributes.ContentState.smiley
    TimeWidgetAttributes.ContentState.starEyes
}
