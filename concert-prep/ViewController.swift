//
//  ViewController.swift
//  concert-prep
//
//  Created by Ibrahim Berat Kaya on 5/7/23.
//

import MediaPlayer
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
        view.addSubview(generateButton)
        
        webview.snp.makeConstraints { make in
            make.top.left.right.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(generateButton.snp.top)
        }
        
        generateButton.snp.makeConstraints { make in
            make.bottom.left.right.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(50)
        }
        
        generateButton.addTarget(self, action: #selector(onGeneratePress), for: .touchUpInside)
        
        webViewURLObserver = webview.observe(\.url, options: .new) { _, change in
            print("URL: \(String(describing: change.newValue))")
            // The webview parameter is the webview whose url changed
            // The change parameter is a NSKeyvalueObservedChange
            // n.b.: you don't have to deregister the observation;
            // this is handled automatically when webViewURLObserver is dealloced.
        }
        
        let myURL = URL(string: "https://www.setlist.fm/")
        let myRequest = URLRequest(url: myURL!)
        webview.load(myRequest)
    }
    
    let webview: WKWebView = {
        let view = WKWebView()
        // songPart
        view.scrollView.minimumZoomScale = 1
        view.scrollView.maximumZoomScale = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let generateButton: UIButton = {
        let view = UIButton()
        view.setTitle("Generate Playlist", for: .normal)
        view.setTitleColor(.blue, for: .normal)
        view.setTitle("Generating", for: .disabled)
        view.setTitleColor(.gray, for: .disabled)
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    @objc func onGeneratePress() {
        generateButton.isEnabled = false
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
                                           
                                           Task {
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
                                                   
                                                   for await song in group {
                                                       if let song {
                                                           playlistSongs.append(song)
                                                       }
                                                   }
                                                   
                                                   var nullableSortedPlaylist = [Song?](repeating: nil, count: songs.count)
                                                   
                                                   playlistSongs.forEach { obj in
                                                       let index = Array(obj)[0].key
                                                       let value = Array(obj)[0].value
                                                       nullableSortedPlaylist[index] = value
                                                   }
                                                   
                                                   let sortedPlaylist: [Song] = nullableSortedPlaylist.compactMap({ $0 })
                                                   
                                                   let date = Date()
                                                   
                                                   let playlistName = "\(artist ?? sortedPlaylist.first?.title ?? "123") - \(date.get(.month))/\(date.get(.day))"
                                                   
                                                   let playlist = try? await MusicLibrary.shared.createPlaylist(name: playlistName)
                                                   
                                                   if let playlist {
                                                       _ = try? await MusicLibrary.shared.edit(playlist, items: sortedPlaylist)
                                                   }
                                                   
                                                   let alert = UIAlertController(title: "Completed", message: (artist != nil) ? "Check Apple Music for your playlist for \(artist!)." : "Check Apple Music for your playlist", preferredStyle: .alert)
                                                   alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Completed"), style: .default, handler: { _ in
                                                       let url = URL(string: "music://")!
                                                       UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                                   }))
                                                   self.present(alert, animated: true, completion: nil)
                                                   self.generateButton.isEnabled = true
                                               }
                                           }
                
                                       } catch {
                                           print(error.localizedDescription)
                                           self.generateButton.isEnabled = true
                                       }
                                   })
    }
}
