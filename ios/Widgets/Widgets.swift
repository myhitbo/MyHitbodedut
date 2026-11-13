import SwiftUI
import WidgetKit

/// Le widget vide de la tâche 3 (recette R1, geste 5). Les vrais widgets : tâche 25.
@main
struct WidgetsMyHitbodedut: WidgetBundle {
    var body: some Widget {
        WidgetVide()
    }
}

struct WidgetVide: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "vide", provider: Fournisseur()) { _ in
            Text("MyHitbodedut")
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("MyHitbodedut")
        .description("Widget vide de la première installation.")
        .supportedFamilies([.systemSmall])
    }
}

struct Moment: TimelineEntry {
    let date: Date
}

struct Fournisseur: TimelineProvider {
    func placeholder(in context: Context) -> Moment {
        Moment(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (Moment) -> Void) {
        completion(Moment(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Moment>) -> Void) {
        completion(Timeline(entries: [Moment(date: .now)], policy: .never))
    }
}
