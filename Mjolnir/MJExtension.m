#import "MJExtension.h"
#import "MJConfigUtils.h"
#import "MJSecurityUtils.h"
#import "MJFileUtils.h"
#import "MJVersionUtils.h"
#import "MJLua.h"

@implementation MJExtension

+ (BOOL)supportsSecureCoding { return YES; }

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
        self.author = [decoder decodeObjectOfClass:[NSString class] forKey:@"author"];
        self.version = [decoder decodeObjectOfClass:[NSString class] forKey:@"version"];
        self.tarfile = [decoder decodeObjectOfClass:[NSString class] forKey:@"tarfile"];
        self.tarsha = [decoder decodeObjectOfClass:[NSString class] forKey:@"tarsha"];
        self.website = [decoder decodeObjectOfClass:[NSString class] forKey:@"website"];
        self.license = [decoder decodeObjectOfClass:[NSString class] forKey:@"license"];
        self.desc = [decoder decodeObjectOfClass:[NSString class] forKey:@"description"];
        self.dependencies = [decoder decodeObjectOfClass:[NSArray class] forKey:@"dependencies"];
        self.changelog = [decoder decodeObjectOfClass:[NSString class] forKey:@"changelog"];
        self.previous = [decoder decodeObjectOfClass:[NSString class] forKey:@"previous"];
        self.minosx = [decoder decodeObjectOfClass:[NSString class] forKey:@"minosx"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.author forKey:@"author"];
    [encoder encodeObject:self.version forKey:@"version"];
    [encoder encodeObject:self.tarfile forKey:@"tarfile"];
    [encoder encodeObject:self.tarsha forKey:@"tarsha"];
    [encoder encodeObject:self.website forKey:@"website"];
    [encoder encodeObject:self.license forKey:@"license"];
    [encoder encodeObject:self.desc forKey:@"description"];
    [encoder encodeObject:self.dependencies forKey:@"dependencies"];
    [encoder encodeObject:self.changelog forKey:@"changelog"];
    [encoder encodeObject:self.previous forKey:@"previous"];
    [encoder encodeObject:self.minosx forKey:@"minosx"];
}

+ (MJExtension*) extensionWithJSON:(NSDictionary*)json {
    MJExtension* ext = [[MJExtension alloc] init];
    ext.name = [json objectForKey:@"name"];
    ext.author = [json objectForKey:@"author"];
    ext.version = [json objectForKey:@"version"];
    ext.license = [json objectForKey:@"license"];
    ext.tarfile = [json objectForKey:@"tarfile"];
    ext.tarsha = [json objectForKey:@"sha"];
    ext.website = [json objectForKey:@"website"];
    ext.desc = [json objectForKey:@"description"];
    ext.dependencies = [json objectForKey:@"deps"];
    ext.changelog = [json objectForKey:@"changelog"];
    ext.previous = [json objectForKey:@"previous"];
    ext.minosx = [json objectForKey:@"minosx"];
    return ext;
}

- (BOOL) canInstall {
    return (MJVersionFromOSX() >= MJVersionFromString(self.minosx));
}

- (BOOL) isEqual:(MJExtension*)other {
    return [self isKindOfClass:[other class]] && [self.tarsha isEqualToString: other.tarsha];
}

- (NSUInteger) hash {
    return [self.tarsha hash];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"<Ext: %@ %@ - %@>", self.name, self.version, self.tarsha];
}

- (void) install:(void(^)(NSError*))done {
    MJDownloadFile(self.tarfile, ^(NSError *err, NSData *tgzdata) {
        if (err) {
            done(err);
            return;
        }
        
        NSError* __autoreleasing error;
        if (!MJVerifyTgzData(tgzdata, self.tarsha, &error)) {
            NSMutableDictionary* userinfo = [@{NSLocalizedDescriptionKey: @"Extension's SHA1 doesn't hold up."} mutableCopy];
            if (error) [userinfo setObject:error forKey:NSUnderlyingErrorKey];
            done([NSError errorWithDomain:@"Mjolnir" code:0 userInfo:userinfo]);
            return;
        }
        
        if (!MJUntar(tgzdata, MJConfigExtensionDir(self.name), &error)) {
            done(error);
            return;
        }
        
        MJLuaLoadModule(self.name);
        
        done(nil);
    });
}

- (void) uninstall:(void(^)(NSError*))done {
    MJLuaUnloadModule(self.name);
    
    NSError* __autoreleasing error;
    if ([[NSFileManager defaultManager] removeItemAtPath:MJConfigExtensionDir(self.name) error:&error])
        error = nil;
    
    done(error);
}

@end
