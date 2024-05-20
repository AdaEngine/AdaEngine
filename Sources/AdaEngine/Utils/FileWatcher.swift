//
//  FileWatcher.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/19/24.
//

import Foundation

// TODO: Add cross-platoform getting FileDescriptor

public final class FileWatcher {

    let url: URL

    public enum Event {
        case delete
        case rename
        case update(Data)
    }

    enum Error: Swift.Error {
        case failedToOpen
    }

    public init(url: URL) {
        self.url = url
    }

    public func observe(on queue: DispatchQueue? = nil, block: @escaping (FileWatcher.Event) -> Void) throws -> Cancellable {
        let handle = open(url.path(), O_EVTONLY)

        if handle == -1 {
            throw Error.failedToOpen
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: handle,
            eventMask: [.delete, .write, .extend, .attrib, .link, .rename, .revoke],
            queue: queue
        )

        let cancel: () -> Void = {
            close(handle)
            return
        }

        source.setEventHandler {
            let data = source.data
            
            let event: Event
            switch data {
            case .delete:
                event = Event.delete
            case .rename:
                event = Event.rename
            default:
                do {
                    let data = try Data(contentsOf: self.url)
                    event = Event.update(data)
                } catch {
                    print("Failed to update data")
                    return
                }
            }

            block(event)

            if data.contains(.delete) || data.contains(.rename) {
                cancel()
            }
        }

        source.setCancelHandler {
            cancel()
        }

        source.resume()

        return AnyCancellable(cancel)
    }

}
