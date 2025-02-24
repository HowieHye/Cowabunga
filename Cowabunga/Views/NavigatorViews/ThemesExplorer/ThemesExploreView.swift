//
//  ExploreView.swift
//  Cowabunga
//
//  Created by sourcelocation on 30/01/2023.
//

import SwiftUI
import CachedAsyncImage

@available(iOS 15.0, *)
struct ThemesExploreView: View {
    
    @ObservedObject var cowabungaAPI = CowabungaAPI.shared
    
    // lazyvgrid
    @State private var gridItemLayout = [GridItem(.adaptive(minimum: 250))]
    @State private var themes: [DownloadableTheme] = []
    
    @State var submitThemeAlertShown = false
    
    @State var themeTypeSelected = 0
    @State var themeTypeShown = DownloadableTheme.ThemeType.icon
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                        // refresh
                        themes.removeAll()
                        Haptic.shared.play(.light)
                        //URLCache.imageCache.removeAllCachedResponses()
                        loadThemes()
                    }
                    VStack {
                        Picker("", selection: $themeTypeSelected) {
                            Text("Icons").tag(0)
                            Text("Passcodes").tag(1)
                            if LockManager.deviceLockPath[UIDevice().machineName] != nil {
                                Text("Locks").tag(2)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 24)
                    
                    if themes.isEmpty {
                        ProgressView()
                            .scaleEffect(1.75)
                            .navigationTitle("Explore")
                    } else {
                        LazyVGrid(columns: gridItemLayout) {
                            ForEach(themes) { theme in
                                Button {
                                    downloadTheme(theme: theme)
                                } label: {
                                    VStack(spacing: 0) {
                                        CachedAsyncImage(url: cowabungaAPI.getPreviewURLForTheme(theme: theme), urlCache: .imageCache) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(maxWidth: .infinity)
                                                .cornerRadius(10, corners: .topLeft)
                                                .cornerRadius(10, corners: .topRight)
                                        } placeholder: {
                                            Color.gray
                                                .frame(height: 192)
                                        }
                                        HStack {
                                            VStack(spacing: 4) {
                                                HStack {
                                                    Text(theme.name)
                                                        .foregroundColor(Color(uiColor14: .label))
                                                        .minimumScaleFactor(0.5)
                                                    Spacer()
                                                }
                                                HStack {
                                                    Text(theme.contact.values.first ?? "Unknown author")
                                                        .foregroundColor(.secondary)
                                                        .font(.caption)
                                                        .minimumScaleFactor(0.5)
                                                    Spacer()
                                                }
                                            }
                                            .lineLimit(1)
                                            Spacer()
                                            Image(systemName: "arrow.down.circle")
                                                .foregroundColor(.blue)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(height: 58)
                                    }
                                }
                                .frame(minWidth: themeTypeShown == .icon ? 250 : 150)
//                                .frame(height: 250)
                                .background(Color(uiColor14: .secondarySystemBackground))
                                .cornerRadius(10)
                                .padding(4)
                            }
                        }
                        .padding()
                    }
                }
                .coordinateSpace(name: "pullToRefresh")
                .navigationTitle("Explore")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            submitThemeAlertShown = true
                        } label: {
                            Image(systemName: "paperplane")
                        }
                    }
                }
            }
            .onAppear {
                loadThemes()
            }
            .alert("Submit themes", isPresented: $submitThemeAlertShown, actions: {
                Button("Join Discord", role: .none, action: {
                    UIApplication.shared.open(URL(string: "https://discord.gg/zTPFJuQfdw")!)
                })
                Button("OK", role: .cancel, action: {})
            }, message: {
                Text("Currently to submit themes for other people to see and use, we have to review them on our Discord in #showcase channel.")
                
            })
            
            //            .sheet(isPresented: $showLogin, content: { LoginView() })
            // maybe later
            
            .onChange(of: themeTypeSelected) { newValue in
                let map = [0: DownloadableTheme.ThemeType.icon, 1: .passcode, 2: .lock]
                themeTypeShown = map[newValue]!
                
                themes.removeAll()
                loadThemes()
                
                gridItemLayout = [GridItem(.adaptive(minimum: themeTypeShown == .icon ? 250 : 150))]
            }
        }
        .navigationViewStyle(.stack)
    }
    
    func loadThemes() {
        Task {
            do {
                themes = try await cowabungaAPI.fetchThemes(type: themeTypeShown).shuffled()
            } catch {
                UIApplication.shared.alert(body: "Error occured while fetching themes. \(error.localizedDescription)")
            }
        }
    }
    
    func downloadTheme(theme: DownloadableTheme) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        UIApplication.shared.alert(title: "Downloading \(theme.name)...", body: "Please wait", animated: false, withButton: false)
        
        // create the folder
        Task {
            do {
                try await cowabungaAPI.downloadTheme(theme: theme)
                Haptic.shared.notify(.success)
                UIApplication.shared.dismissAlert(animated: true)
                UIApplication.shared.alert(title: NSLocalizedString("Success!", comment: ""), body: "The theme was successfully downloaded and saved!")
            } catch {
                print("Could not download passcode theme: \(error.localizedDescription)")
                Haptic.shared.notify(.error)
                UIApplication.shared.dismissAlert(animated: true)
                UIApplication.shared.alert(title: "Could not download theme!", body: error.localizedDescription)
            }
        }
    }
}

struct PullToRefresh: View {
    var coordinateSpaceName: String
    var onRefresh: ()->Void
    
    @State var needRefresh: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            if (geo.frame(in: .named(coordinateSpaceName)).midY > 50) {
                Spacer()
                    .onAppear {
                        needRefresh = true
                    }
            } else if (geo.frame(in: .named(coordinateSpaceName)).maxY < 10) {
                Spacer()
                    .onAppear {
                        if needRefresh {
                            needRefresh = false
                            onRefresh()
                        }
                    }
            }
            HStack {
                Spacer()
                if needRefresh {
                    ProgressView()
                        .scaleEffect(1.75)
                        .onAppear {
                            Haptic.shared.play(.light)
                        }
                } else {
                    Text("")
                }
                Spacer()
            }
        }.padding(.top, -50)
    }
}

@available(iOS 15.0, *)
struct ThemesExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ThemesExploreView()
            .environmentObject(CowabungaAPI())
    }
}
