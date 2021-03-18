//
//  FFCacheQueue.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation

class FFCacheQueue<T> {
    private var storage = [T]()
    private var mutex = pthread_mutex_t.init()
}
extension FFCacheQueue {
    public func count() -> Int {
        pthread_mutex_lock(&mutex)
        defer {
            pthread_mutex_unlock(&mutex)
        }
        return storage.count
    }
    public func enqueue(_ obj: T) {
        pthread_mutex_lock(&mutex)
        defer {
            pthread_mutex_unlock(&mutex)
        }
        self.storage.insert(obj, at: 0)
    }
    public func dequeue() -> T? {
        pthread_mutex_lock(&mutex)
        defer {
            pthread_mutex_unlock(&mutex)
        }
        return self.storage.popLast()
    }
    public func clean() {
        pthread_mutex_lock(&mutex)
        defer {
            pthread_mutex_unlock(&mutex)
        }
        self.storage.removeAll()
    }
    
}
