//
//  DependencyResolver.swift
//  Weaver
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

public protocol DependencyResolver {
    
    func resolve<S>(_ serviceType: S.Type, name: String?) -> S
    
    func resolve<S, P1>(_ serviceType: S.Type, name: String?, parameter: P1) -> S
    
    func resolve<S, P1, P2>(_ serviceType: S.Type, name: String?, parameters: P1, _: P2) -> S

    func resolve<S, P1, P2, P3>(_ serviceType: S.Type, name: String?, parameters: P1, _: P2, _: P3) -> S

    func resolve<S, P1, P2, P3, P4>(_ serviceType: S.Type, name: String?, parameters: P1, _: P2, _: P3, _: P4) -> S
}
