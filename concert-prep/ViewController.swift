//
//  ViewController.swift
//  concert-prep
//
//  Created by Ibrahim Berat Kaya on 5/7/23.
//

import MusicKit
import SnapKit
import StoreKit
import SwiftSoup
import UIKit
import WebKit

class ViewController: UIViewController {
    var webViewURLObserver: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.backgroundColor = .white
        view.addSubview(webview)
        view.addSubview(webviewBottomContainer)
        view.addSubview(bottomSafeAreaView)
        
        webviewBottomContainer.addSubview(generateButton)
        webviewBottomContainer.addSubview(progressBar)
        
        webview.snp.makeConstraints { make in
            make.top.left.right.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(webviewBottomContainer.snp.top)
        }
        
        webviewBottomContainer.snp.makeConstraints { make in
            make.bottom.equalTo(bottomSafeAreaView.snp.top)
            make.left.right.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(48)
        }
        
        generateButton.snp.makeConstraints { make in
            make.bottom.left.right.top.equalTo(webviewBottomContainer)
        }
        
        progressBar.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.left.right.equalTo(webviewBottomContainer).inset(40)
            make.height.equalTo(6)
        }
        
        generateButton.addTarget(self, action: #selector(onGeneratePress), for: .touchUpInside)
        
        webViewURLObserver = webview.observe(\.url, options: .new) { _, change in
            print("URL: \(String(describing: change.newValue))")
        }
        
        let myURL = URL(string: "https://www.setlist.fm/")
        let myRequest = URLRequest(url: myURL!)
        webview.load(myRequest)
        
        webview.configuration.userContentController.addUserScript(getZoomDisableScript())
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        bottomSafeAreaView.snp.makeConstraints { make in
            make.bottom.left.right.equalToSuperview()
            make.top.equalTo(webviewBottomContainer.snp.bottom)
            make.height.equalTo(view.safeAreaInsets.bottom)
        }
    }
    
    let webview: WKWebView = {
        let view = WKWebView()
        view.scrollView.minimumZoomScale = 1
        view.scrollView.maximumZoomScale = 1
        view.allowsBackForwardNavigationGestures = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let webviewBottomContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 235/255, green: 235/255, blue: 235/255, alpha: 1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let bottomSafeAreaView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 235/255, green: 235/255, blue: 235/255, alpha: 1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let generateButton: UIButton = {
        let view = UIButton()
        view.setTitle("Generate Playlist", for: .normal)
        view.setTitleColor(.blue, for: .normal)
        view.setTitle("Generating", for: .disabled)
        view.setTitleColor(.gray, for: .disabled)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let progressBar: UIProgressView = {
        let view = UIProgressView()
        view.progressTintColor = UIColor(red: 80/255, green: 205/255, blue: 80/255, alpha: 1)
        view.trackTintColor = UIColor(red: 200/255, green: 220/255, blue: 200/255, alpha: 1)
        view.progress = 0.0
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    func increaseProgressBarValue(_ progress: Float) {
        progressBar.setProgress(progressBar.progress + progress, animated: true)
    }
    
    func setProgressBarValue(_ progress: Float) {
        progressBar.setProgress(0.05, animated: true)
    }
    
    @objc func onGeneratePress() {
        generateButton.isHidden = true
        progressBar.isHidden = false
        var timerCtr = 0
        // Display first 20% progress with a timer
        Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { timer in
            timerCtr += 1
            self.increaseProgressBarValue(0.05)
            if timerCtr == 4 {
                timer.invalidate()
            }
        }
        webview.evaluateJavaScript("document.documentElement.outerHTML.toString()",
                                   completionHandler: { (html: Any?, error: Error?) in
                                       do {
                                           guard let html = html as? String else {
                                               return
                                           }
                                           let doc: Document = try SwiftSoup.parse(html)
                                           let songElements = try doc.select(".songPart")
                                           let songs: [String] = try songElements.map { i in
                                               try i.text()
                                           }
                                           
                                           let artistElement = try doc.select(".setlistHeadline h1 strong span a span")
                                           let artist = try artistElement.map { i in
                                               try i.text()
                                           }.last
                                           
                                           if songs.isEmpty {
                                               self.progressBar.isHidden = true
                                               self.setProgressBarValue(0)
                                               self.generateButton.isHidden = false
                                               return
                                           }
                                           
                                           Task {
                                               var ctr = 0.0
                                               await withTaskGroup(of: [Int: Song]?.self) { group in
                                                   var playlistSongs = [[Int: Song]]()
                                                   for (index, i) in songs.enumerated() {
                                                       group.addTask {
                                                           var request: MusicCatalogSearchRequest
                                                           if let artist {
                                                               request = MusicCatalogSearchRequest(term: "\(artist) \(i)", types: [Song.self, Artist.self])
                                                           } else {
                                                               request = MusicCatalogSearchRequest(term: "\(i)", types: [Song.self])
                                                           }
                                                           request.includeTopResults = true
                                                           request.limit = 20
                                                           
                                                           let response = try? await request.response()
                                                           
                                                           let songs = response?.songs
                                                           
                                                           if let songs {
                                                               if let artist {
                                                                   for j in songs {
                                                                       if levDis(j.artistName, artist) < 3 || j.artistName.contains(artist) || artist.contains(j.artistName) {
                                                                           return [index: j]
                                                                       }
                                                                   }
                                                               } else {
                                                                   if let song = songs.first {
                                                                       return [index: song]
                                                                   }
                                                               }
                                                           }
                                                           return nil
                                                       }
                                                   }
                                                   
                                                   // Do 60% of progress
                                                   for await song in group {
                                                       if let song {
                                                           playlistSongs.append(song)
                                                           ctr += 1.0
                                                           
                                                           let progress = ctr/Double(songs.count)
                                                           
                                                           self.increaseProgressBarValue(Float(0.6 * progress))
                                                       }
                                                   }
                                                   
                                                   var nullableSortedPlaylist = [Song?](repeating: nil, count: songs.count)
                                                   
                                                   playlistSongs.forEach { obj in
                                                       let index = Array(obj)[0].key
                                                       let value = Array(obj)[0].value
                                                       nullableSortedPlaylist[index] = value
                                                   }
                                                   
                                                   self.increaseProgressBarValue(0.05)
                                                   
                                                   let sortedPlaylist: [Song] = nullableSortedPlaylist.compactMap { $0 }
                                                   
                                                   let date = Date()
                                                   
                                                   let playlistName = "\(artist ?? sortedPlaylist.first?.title ?? "123") - \(date.get(.month))/\(date.get(.day))"
                                                   
                                                   let playlist = try? await MusicLibrary.shared.createPlaylist(name: playlistName)
                                                   
                                                   // Display another 10% progress
                                                   self.increaseProgressBarValue(0.1)
                                                   
                                                   if let playlist {
                                                       _ = try? await MusicLibrary.shared.edit(playlist, items: sortedPlaylist)
                                                   }
                                                   
                                                   // Display another 5% progress
                                                   self.increaseProgressBarValue(0.05)
                                                   
                                                   let alert = UIAlertController(title: "Completed", message: (artist != nil) ? "Check Apple Music for your playlist for \(artist!)." : "Check Apple Music for your playlist", preferredStyle: .alert)
                                                   alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Completed"), style: .default, handler: { _ in
                                                       let url = URL(string: "music://")!
                                                       UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                                   }))
                                                   self.present(alert, animated: true, completion: nil)
                                                   
                                                   
                                                   self.progressBar.isHidden = true
                                                   self.setProgressBarValue(0.0)
                                                   self.generateButton.isHidden = false
                                               }
                                           }
                
                                       } catch {
                                           print(error.localizedDescription)
                                           
                                           self.progressBar.isHidden = true
                                           self.setProgressBarValue(0.0)
                                           self.generateButton.isHidden = false
                                       }
                                   })
    }
    
    // Taken from https://stackoverflow.com/a/58665789
    private func getZoomDisableScript() -> WKUserScript {
        let source: String = "var meta = document.createElement('meta');" +
            "meta.name = 'viewport';" +
            "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" +
            "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
}
