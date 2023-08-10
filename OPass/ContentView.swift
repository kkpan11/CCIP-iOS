//
//  ContentView.swift
//  OPass
//
//  Created by 張智堯 on 2022/2/28.
//  2023 OPass.
//

import SwiftUI

struct ContentView: View {
    // MARK: - Variables
    @Binding var url: URL?
    @EnvironmentObject var store: OPassStore
    @State private var error: Error?
    @State private var handlingURL = false
    @State private var isEventListPresented = false
    @State private var isHttp403AlertPresented = false
    @State private var isInvalidURLAlertPresented = false

    // MARK: - Views
    var body: some View {
        Group {
            switch viewState {
            case .ready(let event):
                RootView()
                    .environmentObject(event)
            case .loading:
                ProgressView("Loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        do {
                            try await store.loadEvent()
                        } catch { self.error = error }
                    }
            case .empty:
                EventListView()
            case .error:
                ErrorWithRetryView {
                    self.error = nil
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: store.eventId) { _ in
                    self.error = nil
                }
            }
        }
        .background(Color("SectionBackgroundColor"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEventListPresented) { EventListView() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                SFButton(systemName: "rectangle.stack") {
                    isEventListPresented.toggle()
                }
            }

            ToolbarItem(placement: .principal) {
                VStack {
                    Text(store.event?.config.title.localized() ?? "OPass")
                        .font(.headline)
                    if let userId = store.event?.userId, userId != "nil" {
                        Text(userId)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(value: RootDestinations.settings) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .overlay {
            if self.url != nil {
                ProgressView("LOGGINGIN")
                    .task {
                        self.isEventListPresented = false
                        await parseUniversalLinkAndURL(url!)
                    }
                    .alert("InvalidURL", isPresented: $isInvalidURLAlertPresented) {
                        Button("OK", role: .cancel) {
                            self.url = nil
                            if store.event == nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.isEventListPresented = true
                                }
                            }
                        }
                    } message: {
                        Text("InvalidURLOrTokenContent")
                    }
                    .http403Alert(title: "CouldntVerifiyYourIdentity", isPresented: $isHttp403AlertPresented) {
                        self.url = nil
                        if store.event == nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.isEventListPresented = true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color("SectionBackgroundColor").edgesIgnoringSafeArea(.all))
            }
        }
    }

    // MARK: - Functions
    private func parseUniversalLinkAndURL(_ url: URL) async {
        let params = URLComponents(string: "?" + (url.query ?? ""))?.queryItems

        // Select event
        guard let eventId = params?.first(where: { $0.name == "event_id"})?.value else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isInvalidURLAlertPresented = true
            }
            return
        }
        store.eventId = eventId
        if eventId != store.event?.id { store.eventLogo = nil }
        // Login
        guard let token = params?.first(where: { $0.name == "token" })?.value else {
            DispatchQueue.main.async {
                self.url = nil
            }
            return
        }

        do {
            if try await store.loginCurrentEvent(with: token) {
                DispatchQueue.main.async { self.url = nil }
                await store.event?.loadLogos()
                return
            }
        } catch APIManager.LoadError.forbidden {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isHttp403AlertPresented = true
            }
            return
        } catch {}

        // Error
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isInvalidURLAlertPresented = true
        }
    }
}

// MARK: ViewState
extension ContentView {
    private enum ViewState {
        case ready(EventStore)
        case loading
        case empty // Landing page?
        case error
    }

    private var viewState: ViewState {
        guard error == nil else { return .error }
        guard let eventID = store.eventId else { return .empty }
        guard let event = store.event, eventID == event.id else { return .loading }
        return .ready(event)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(url: .constant(nil))
            .environmentObject(OPassStore.mock())
    }
}
#endif