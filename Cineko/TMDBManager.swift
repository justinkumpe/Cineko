//
//  TMDBManager.swift
//  Cineko
//
//  Created by Jovit Royeca on 04/04/2016.
//  Copyright © 2016 Jovito Royeca. All rights reserved.
//

import Foundation
import KeychainAccess

enum TMDBError: ErrorType {
    case NoAPIKey
    case NoSessionID
}

struct TMDBConstants {
    static let APIKey          = "api_key"
    static let APIURL          = "https://api.themoviedb.org/3"
    static let SignupURL       = "https://www.themoviedb.org/account/signup"
    static let AuthenticateURL = "https://www.themoviedb.org/authenticate"
    static let ImageURL        = "https://image.tmdb.org/t/p"
    
    static let BackdropSizes = [
        "w300",
        "w780",
        "w1280",
        "original"]
    
    static let LogoSizes = [
        "w45",
        "w92",
        "w154",
        "w185",
        "w300",
        "w500",
        "original"]
    
    static let PosterSizes = [
        "w92",
        "w154",
        "w185",
        "w342",
        "w500",
        "w780",
        "original"]
    
    static let ProfileSizes = [
        "w45",
        "w92", // not include in TMDB configuration
        "w185",
        "h632",
        "original"]
    
    static let StillSizes = [
        "w92",
        "w185",
        "w300",
        "original"]
    
    struct iPad {
        struct Keys {
            static let RequestToken     = "request_token"
            static let RequestTokenDate = "request_token_date"
            static let SessionID        = "session_id"
        }
    }
    
    struct Authentication {
        struct TokenNew {
            static let Path = "/authentication/token/new"
            struct Keys {
                static let RequestToken = "request_token"
            }
        }
        
        struct SessionNew {
            static let Path = "/authentication/session/new"
            struct Keys {
                static let SessionID = "session_id"
            }
        }
    }
    
    struct Movies {
        struct NowPlaying {
            static let Path = "/movie/now_playing"
        }
        struct Details {
            static let Path = "/movie/{id}"
        }
        struct Images {
            static let Path = "/movie/{id}/images"
        }
        struct Credits {
            static let Path = "/movie/{id}/credits"
        }
    }
    
    struct TVShows {
        struct OnTheAir {
            static let Path = "/tv/on_the_air"
        }
        struct AiringToday {
            static let Path = "/tv/airing_today"
        }
        struct Details {
            static let Path = "/tv/{id}"
        }
        struct Images {
            static let Path = "/tv/{id}/images"
        }
        struct Credits {
            static let Path = "/tv/{id}/credits"
        }
    }
    
    struct People {
        struct Popular {
            static let Path = "/person/popular"
        }
        struct Credits {
            static let Path = "/person/{id}/combined_credits"
        }
    }
}

enum ImageType : Int {
    case MovieBackdrop
    case MoviePoster
    case TVShowBackdrop
    case TVShowPoster
}

enum CreditType : String {
    case Cast = "cast",
        Crew = "crew",
        GuestStar = "guest_star"
}

enum CreditParent : String {
    case Job = "Job",
        Movie = "Movie",
        Person = "Person",
        TVEpisode = "TVEpisode",
        TVSeason = "TVSeason",
        TVShow = "TVShow"
}

class TMDBManager: NSObject {
    let keychain = Keychain(server: "\(TMDBConstants.APIURL)", protocolType: .HTTPS)

    // MARK: Variables
    private var apiKey:String?
    
    // MARK: Setup
    func setup(apiKey: String) {
        self.apiKey = apiKey
        checkFirstRun()
    }
    
    // MARK: iPad
    func checkFirstRun() {
        if !NSUserDefaults.standardUserDefaults().boolForKey("FirstRun") {
            // remove prior keychain items if this is our first run
            TMDBManager.sharedInstance().keychain[TMDBConstants.iPad.Keys.SessionID] = nil
            TMDBManager.sharedInstance().keychain[TMDBConstants.iPad.Keys.RequestToken] = nil
            NSUserDefaults.standardUserDefaults().removeObjectForKey(TMDBConstants.iPad.Keys.RequestTokenDate)
            
            // then mark this us our first run
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: "FirstRun")
        }
    }
    
    func getAvailableRequestToken() throws -> String? {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        if let requestToken = keychain[TMDBConstants.iPad.Keys.RequestToken],
            let requestTokenDate = NSUserDefaults.standardUserDefaults().valueForKey(TMDBConstants.iPad.Keys.RequestTokenDate) as? NSDate {
            
            // let's calculate the age of the request token
            let interval = requestTokenDate.timeIntervalSinceNow
            let secondsInAnHour:Double = 3600
            let elapsedTime = abs(interval / secondsInAnHour)
            
            // request token's expiration is 1 hour
            if elapsedTime <= 60 {
                return requestToken
                
            } else {
                TMDBManager.sharedInstance().keychain[TMDBConstants.iPad.Keys.SessionID] = nil
                TMDBManager.sharedInstance().keychain[TMDBConstants.iPad.Keys.RequestToken] = nil
                NSUserDefaults.standardUserDefaults().removeObjectForKey(TMDBConstants.iPad.Keys.RequestTokenDate)
            }
        }
        
        return nil
    }
    
    func saveRequestToken(requestToken: String) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        TMDBManager.sharedInstance().keychain[TMDBConstants.iPad.Keys.RequestToken] = requestToken
        NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: TMDBConstants.iPad.Keys.RequestTokenDate)
    }
    
    func removeRequestToken() throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        TMDBManager.sharedInstance().keychain[TMDBConstants.iPad.Keys.RequestToken] = nil
        NSUserDefaults.standardUserDefaults().removeObjectForKey(TMDBConstants.iPad.Keys.RequestTokenDate)
    }
    
    func saveSessionID(sessionID: String) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        TMDBManager.sharedInstance().keychain[TMDBConstants.iPad.Keys.SessionID] = sessionID
    }
    
    func hasSessionID() -> Bool {
        return TMDBManager.sharedInstance().keychain[TMDBConstants.iPad.Keys.SessionID] != nil
    }
    
    // MARK: TMDB Authentication
    func authenticationTokenNew(success: (results: AnyObject!) -> Void, failure: (error: NSError?) -> Void) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        let urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.Authentication.TokenNew.Path)"
        let parameters = [TMDBConstants.APIKey: apiKey!]
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }
    
    func authenticationSessionNew(success: (results: AnyObject!) -> Void, failure: (error: NSError?) -> Void) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        if let requestToken = try getAvailableRequestToken() {
            let httpMethod:HTTPMethod = .Get
            let urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.Authentication.SessionNew.Path)"
            let parameters = [TMDBConstants.APIKey: apiKey!,
                              TMDBConstants.Authentication.TokenNew.Keys.RequestToken: requestToken]
            
            NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
        
        } else {
            failure(error: NSError(domain: "exec", code: 1, userInfo: [NSLocalizedDescriptionKey : "No request token available."]))
        }
    }
    
    // MARK: TMDB Movies
    func moviesNowPlaying(completion: (arrayIDs: [AnyObject], error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        let urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.Movies.NowPlaying.Path)"
        let parameters = [TMDBConstants.APIKey: apiKey!]
        var movieIDs = [NSNumber]()
        
        let success = { (results: AnyObject!) in
            if let dict = results as? [String: AnyObject] {
                if let json = dict["results"] as? [[String: AnyObject]] {
                    for movie in json {
                        let m = ObjectManager.sharedInstance().findOrCreateMovie(movie)
                        if let movieID = m.movieID {
                            movieIDs.append(movieID)
                        }
                    }
                }
            }
            completion(arrayIDs: movieIDs, error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(arrayIDs: movieIDs, error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }

    func movieDetails(movieID: NSNumber, completion: (error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        var urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.Movies.Details.Path)"
        urlString = urlString.stringByReplacingOccurrencesOfString("{id}", withString: "\(movieID)")
        let parameters = [TMDBConstants.APIKey: apiKey!]
    
        let success = { (results: AnyObject!) in
            if let dict = results as? [String: AnyObject] {
                ObjectManager.sharedInstance().updateMovie(dict)
            }
            completion(error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }

    func movieImages(movieID: NSNumber, completion: (error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        var urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.Movies.Images.Path)"
        urlString = urlString.stringByReplacingOccurrencesOfString("{id}", withString: "\(movieID)")
        let parameters = [TMDBConstants.APIKey: apiKey!]
        
        let success = { (results: AnyObject!) in
            let movie = ObjectManager.sharedInstance().findOrCreateMovie([Movie.Keys.MovieID: movieID])
            
            if let dict = results as? [String: AnyObject] {
                if let backdrops = dict["backdrops"] as? [[String: AnyObject]] {
                    for backdrop in backdrops {
                        ObjectManager.sharedInstance().findOrCreateImage(backdrop, imageType: .MovieBackdrop, forObject: movie)
                    }
                }
                
                if let posters = dict["posters"] as? [[String: AnyObject]] {
                    for poster in posters {
                        ObjectManager.sharedInstance().findOrCreateImage(poster, imageType: .MoviePoster, forObject: movie)
                    }
                }
            }
            completion(error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }

    func movieCredits(movieID: NSNumber, completion: (error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        var urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.Movies.Credits.Path)"
        urlString = urlString.stringByReplacingOccurrencesOfString("{id}", withString: "\(movieID)")
        let parameters = [TMDBConstants.APIKey: apiKey!]
        
        let success = { (results: AnyObject!) in
            let movie = ObjectManager.sharedInstance().findOrCreateMovie([Movie.Keys.MovieID: movieID])
            
            if let dict = results as? [String: AnyObject] {
                if let cast = dict["cast"] as? [[String: AnyObject]] {
                    for c in cast {
                        ObjectManager.sharedInstance().findOrCreateCast(c, creditType: .Cast, creditParent: .Movie, forObject: movie)
                    }
                }
                
                if let crew = dict["crew"] as? [[String: AnyObject]] {
                    for c in crew {
                        ObjectManager.sharedInstance().findOrCreateCast(c, creditType: .Crew, creditParent: .Movie, forObject: movie)
                    }
                }
            }
            completion(error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }
    
    // MARK: TMDB TV Shows
    func tvShowsOnTheAir(completion: (arrayIDs: [AnyObject], error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        let urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.TVShows.OnTheAir.Path)"
        let parameters = [TMDBConstants.APIKey: apiKey!]
        var tvShowIDs = [NSNumber]()
        
        let success = { (results: AnyObject!) in
            if let dict = results as? [String: AnyObject] {
                if let json = dict["results"] as? [[String: AnyObject]] {
                    for tvShow in json {
                        let m = ObjectManager.sharedInstance().findOrCreateTVShow(tvShow)
                        if let tvShowID = m.tvShowID {
                            tvShowIDs.append(tvShowID)
                        }
                    }
                }
            }
            completion(arrayIDs: tvShowIDs, error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(arrayIDs: tvShowIDs, error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }

    func tvShowsAiringToday(completion: (arrayIDs: [AnyObject], error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        let urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.TVShows.AiringToday.Path)"
        let parameters = [TMDBConstants.APIKey: apiKey!]
        var tvShowIDs = [NSNumber]()
        
        let success = { (results: AnyObject!) in
            if let dict = results as? [String: AnyObject] {
                if let json = dict["results"] as? [[String: AnyObject]] {
                    for tvShow in json {
                        let m = ObjectManager.sharedInstance().findOrCreateTVShow(tvShow)
                        if let tvShowID = m.tvShowID {
                            tvShowIDs.append(tvShowID)
                        }
                    }
                }
            }
            completion(arrayIDs: tvShowIDs, error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(arrayIDs: tvShowIDs, error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }

    func tvShowDetails(tvShowID: NSNumber, completion: (error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        var urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.TVShows.Details.Path)"
        urlString = urlString.stringByReplacingOccurrencesOfString("{id}", withString: "\(tvShowID)")
        let parameters = [TMDBConstants.APIKey: apiKey!]
        
        let success = { (results: AnyObject!) in
            if let dict = results as? [String: AnyObject] {
                ObjectManager.sharedInstance().updateTVShow(dict)
            }
            completion(error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }

    func tvShowImages(tvShowID: NSNumber, completion: (error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        var urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.TVShows.Images.Path)"
        urlString = urlString.stringByReplacingOccurrencesOfString("{id}", withString: "\(tvShowID)")
        let parameters = [TMDBConstants.APIKey: apiKey!]
        
        let success = { (results: AnyObject!) in
            let tvShow = ObjectManager.sharedInstance().findOrCreateTVShow([TVShow.Keys.TVShowID: tvShowID])
            
            if let dict = results as? [String: AnyObject] {
                if let backdrops = dict["backdrops"] as? [[String: AnyObject]] {
                    for backdrop in backdrops {
                        ObjectManager.sharedInstance().findOrCreateImage(backdrop, imageType: .TVShowBackdrop, forObject: tvShow)
                    }
                }
            }
            completion(error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }

    func tvShowCredits(tvShowID: NSNumber, completion: (error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        var urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.TVShows.Credits.Path)"
        urlString = urlString.stringByReplacingOccurrencesOfString("{id}", withString: "\(tvShowID)")
        let parameters = [TMDBConstants.APIKey: apiKey!]
        
        let success = { (results: AnyObject!) in
            let tvShow = ObjectManager.sharedInstance().findOrCreateTVShow([TVShow.Keys.TVShowID: tvShowID])
            
            if let dict = results as? [String: AnyObject] {
                if let cast = dict["cast"] as? [[String: AnyObject]] {
                    for c in cast {
                        ObjectManager.sharedInstance().findOrCreateCast(c, creditType: .Cast, creditParent: .TVShow, forObject: tvShow)
                    }
                }
                
                if let crew = dict["crew"] as? [[String: AnyObject]] {
                    for c in crew {
                        ObjectManager.sharedInstance().findOrCreateCast(c, creditType: .Crew, creditParent: .TVShow, forObject: tvShow)
                    }
                }
            }
            completion(error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }
    
    // MARK: TMDB People
    func peoplePopular(completion: (arrayIDs: [AnyObject], error: NSError?) -> Void?) throws {
        guard (apiKey) != nil else {
            throw TMDBError.NoAPIKey
        }
        
        let httpMethod:HTTPMethod = .Get
        let urlString = "\(TMDBConstants.APIURL)\(TMDBConstants.People.Popular.Path)"
        let parameters = [TMDBConstants.APIKey: apiKey!]
        var personIDs = [NSNumber]()
        
        let success = { (results: AnyObject!) in
            if let dict = results as? [String: AnyObject] {
                if let json = dict["results"] as? [[String: AnyObject]] {
                    for person in json {
                        let m = ObjectManager.sharedInstance().findOrCreatePerson(person)
                        if let personID = m.personID {
                            personIDs.append(personID)
                        }
                    }
                }
            }
            completion(arrayIDs: personIDs, error: nil)
        }
        
        let failure = { (error: NSError?) -> Void in
            completion(arrayIDs: personIDs, error: error)
        }
        
        NetworkManager.sharedInstance().exec(httpMethod, urlString: urlString, headers: nil, parameters: parameters, values: nil, body: nil, dataOffset: 0, isJSON: true, success: success, failure: failure)
    }
    
    // MARK: Shared Instance
    class func sharedInstance() -> TMDBManager {
        
        struct Singleton {
            static var sharedInstance = TMDBManager()
        }
        
        return Singleton.sharedInstance
    }
}
