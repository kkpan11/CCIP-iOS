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
    @StateObject var router = Router()
    @EnvironmentObject var OPassService: OPassStore
    @State private var error: Error? = nil
    @State private var handlingURL = false
    @State private var isEventListPresented = false
    @State private var isHttp403AlertPresented = false
    @State private var isInvalidURLAlertPresented = false
    
    // MARK: - Views
    var body: some View {
        NavigationStack(path: $router.path) {
            VStack {
                switch viewState {
                case .ready(let EventStore):
                    MainView()
                        .environmentObject(EventStore)
                        .navigationDestination(for: Router.mainDestination.self) { destination in
                            switch destination {
                            case .fastpass:
                                FastpassView().environmentObject(EventStore)
                                
                            case .schedule:
                                ScheduleView(EventStore: EventStore)
                                
                            case .scheduleSearch(let schedule):
                                SearchScheduleView(schedule: schedule)
                                    .environmentObject(EventStore)
                                
                            case .sessionDetail(let data):
                                SessionDetailView(data).environmentObject(EventStore)
                                
                            case .ticket:
                                TicketView().environmentObject(EventStore)
                                
                            case .announcement:
                                AnnouncementView().environmentObject(EventStore)
                            }
                        }
                case .loading:
                    ProgressView("Loading")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            do { try await OPassService.loadEvent() }
                            catch { self.error = error }
                        }
                case .empty:
                    VStack {}
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            self.isEventListPresented = true
                        }
                case .error:
                    ErrorWithRetryView {
                        self.error = nil
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: OPassService.eventId) { _ in
                        self.error = nil
                    }
                }
            }
            .background(Color("SectionBackgroundColor"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Router.rootDestination.self) { destination in
                switch destination {
                case .settings:   SettingsView()
                case .appearance: AppearanceView()
                case .developers: DevelopersView()
                }
            }
            .sheet(isPresented: $isEventListPresented) { EventListView() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SFButton(systemName: "rectangle.stack") {
                        isEventListPresented.toggle()
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text(OPassService.event?.config.title.localized() ?? "OPass")
                            .font(.headline)
                        if let userId = OPassService.event?.userId, userId != "nil" {
                            Text(userId)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(value: Router.rootDestination.settings) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .environmentObject(router)
        .environmentObject(OPassService)
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
                            if OPassService.event == nil {
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
                        if OPassService.event == nil {
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
        OPassService.eventId = eventId
        if eventId != OPassService.event?.id { OPassService.eventLogo = nil }
        // Login
        guard let token = params?.first(where: { $0.name == "token" })?.value else {
            DispatchQueue.main.async {
                self.url = nil
            }
            return
        }
        
        do {
            if try await OPassService.loginCurrentEvent(with: token) {
                DispatchQueue.main.async { self.url = nil }
                await OPassService.event?.loadLogos()
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
        case empty //Landing page?
        case error
    }
    
    private var viewState: ViewState {
        guard error == nil else { return .error }
        guard let eventID = OPassService.eventId else { return .empty }
        guard let EventStore = OPassService.event, eventID == EventStore.id else { return .loading }
        return .ready(EventStore)
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
