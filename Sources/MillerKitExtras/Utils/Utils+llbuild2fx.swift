import llbuild2
import llbuild2fx

extension LLBFileBackedFunctionCache: FXFunctionCache {
    public func get(key: any llbuild2.LLBKey, props: any llbuild2fx.FXKeyProperties, _ ctx: TSCUtility.Context) -> TSFFutures.LLBFuture<TSFCAS.LLBDataID?> {
        return self.get(key: key, ctx)
    }
    
    public func update(key: any llbuild2.LLBKey, props: any llbuild2fx.FXKeyProperties, value: TSFCAS.LLBDataID, _ ctx: TSCUtility.Context) -> TSFFutures.LLBFuture<Void> {
        return self.update(key: key, value: value, ctx)
    }
}


struct EngineKey { }

public extension Context {
    var engine: FXBuildEngine? {
        get {
            guard let engine = self[ObjectIdentifier(EngineKey.self)] as? FXBuildEngine else {
                return nil
            }
            return engine
        }
        set {
            self[ObjectIdentifier(EngineKey.self)] = newValue
        }
    }
}
