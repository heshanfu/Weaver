//
//  MovieManagerTests.swift
//  SampleTests
//
//  Created by Théophane Rupin on 4/9/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Sample

final class MovieManagerTests: XCTestCase {
    
    var movieManagerDependencyResolverMock: MovieManagerDependencyResolverMock!
    var movieManager: MovieManager!
    
    var movie: Movie {
        return Movie(vote_count: 1, id: 42, video: false, vote_average: 0, title: "test",
                     popularity: 2, poster_path: "test", original_language: "en",
                     original_title: "test", backdrop_path: "test", adult: false,
                     overview: "test", release_date: "01-01-2001")
    }
    
    override func setUp() {
        super.setUp()
        
        movieManagerDependencyResolverMock = MovieManagerDependencyResolverMock()
        movieManager = MovieManager(injecting: movieManagerDependencyResolverMock)
    }
    
    override func tearDown() {
        defer { super.tearDown() }
        
        movieManagerDependencyResolverMock = nil
        movieManager = nil
    }
    
    func test_movieManager_getDiscoverMovies_should_retrieve_an_array_of_movies() {

        let page = Page(page: 2, total_results: 2, total_pages: 10, results: [movie, movie])
        
        let movieAPIMock = movieManagerDependencyResolverMock.movieAPIMock
        movieAPIMock.sendModelRequestResultStub = .success(page)
        
        let expectation = self.expectation(description: "get_movies")
        movieManager.getDiscoverMovies { result in
            switch result {
            case .success(let page):
                XCTAssertEqual(page.results.count, 2)
                XCTAssertEqual(movieAPIMock.modelRequestConfigSpy.first?.path, "/discover/movie")
                XCTAssertEqual(movieAPIMock.modelRequestConfigSpy.count, 1)
                
            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1)
    }
    
    func test_movieManager_getMovie_should_retriave_a_movie() {
        
        let movieAPIMock = movieManagerDependencyResolverMock.movieAPIMock
        movieAPIMock.sendModelRequestResultStub = .success(movie)
        
        let expectation = self.expectation(description: "get_movie")
        movieManager.getMovie(id: 42) { result in
            switch result {
            case .success(let movie):
                XCTAssertEqual(movie.id, 42)
                XCTAssertEqual(movieAPIMock.modelRequestConfigSpy.first?.path, "/movie/42")
                XCTAssertEqual(movieAPIMock.modelRequestConfigSpy.count, 1)
                
            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1)
    }
}
