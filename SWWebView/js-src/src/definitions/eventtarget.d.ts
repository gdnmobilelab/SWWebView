declare module "eventtarget" {
    class EventTarget {
        addEventListener<T>(type: string, listener: (T) => void): void;
        removeEventListener<T>(type: string, listener: (T) => void): void;
        dispatchEvent(ev: Event);
    }
    export default EventTarget;
}
