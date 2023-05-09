//
//  Date.swift
//  concert-prep
//
//  Created by Ibrahim Berat Kaya on 5/8/23.
//

import Foundation


extension Date {
    
    // Taken from https://stackoverflow.com/a/58065902
    func get(_ components: Calendar.Component..., calendar: Calendar = Calendar.current) -> DateComponents {
        return calendar.dateComponents(Set(components), from: self)
    }

    func get(_ component: Calendar.Component, calendar: Calendar = Calendar.current) -> Int {
        return calendar.component(component, from: self)
    }
}
