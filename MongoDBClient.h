//
//  MongoDBClient.h
//  MongoDBClient
//
//  Created by Daniel Parnell on 16/12/12.
//  Copyright (c) 2012 Automagic Software Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OrderedDictionary.h"

@interface MongoObjectId : NSObject

+ (MongoObjectId*)oidWithString:(NSString*)string;

@property(readonly) NSString* string;

@end

@interface MongoTimestamp : NSObject

+(instancetype)timestamp;
+(instancetype)timestampWithDate:(NSDate *)date;

@property (strong) NSDate * date;

-(id)initWithDate:(NSDate *)date;

@end

@interface MongoSymbol : NSObject

+(instancetype)symbolWithString:(NSString *)string;

@property (strong) NSString * string;

-(id)initWithString:(NSString *)string;

@end

@interface MongoUndefined : NSObject
@end

@interface MongoRegex : NSObject

- (id) initWithPattern:(NSString*)pattern andOptions:(NSString*)options;

@property (strong) NSString* pattern;
@property (strong) NSString* options;

@end

@interface MongoDbCursor : NSObject

- (BOOL) next:(OrderedDictionary*)doc withError:(NSError**)error;

@end

@interface MongoDBClient : NSObject

+ (MongoDBClient*) clientWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error;
- (id) initWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error;

- (BOOL) authenticateForDatabase:(NSString*)database withUsername:(NSString*)username password:(NSString*)password andError:(NSError**)error;

- (BOOL) insert:(NSDictionary*) object intoCollection:(NSString*)collection withError:(NSError**)error;
- (NSArray*) find:(id) query inCollection:(NSString*)collection withError:(NSError**)error;
-(NSArray *) find:(id)query columns:(NSDictionary*)columns fromCollection:(NSString*)collection withError:(NSError**)error;
- (NSArray*) find:(id) query columns: (NSDictionary*) columns skip:(NSInteger)toSkip returningNoMoreThan:(NSInteger)limit fromCollection:(NSString*)collection withError:(NSError**)error;
-(OrderedDictionary *)findOne:(id)query inCollection:(NSString *)collection withError:(NSError **)error;
-(OrderedDictionary *)findOne:(id)query columns:(NSDictionary *)columns fromCollection:(NSString *)collection withError:(NSError **)error;
- (BOOL) update:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error;
- (BOOL) upsert:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error;
- (BOOL) updateAll:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error;
- (BOOL) remove:(id)query fromCollection:(NSString*)collection withError:(NSError**)error;
- (NSUInteger) count:(id)query inCollection:(NSString*)collection withError:(NSError**)error;

- (MongoDbCursor*) cursorWithFind:(id) query columns: (NSDictionary*) columns skip:(NSInteger)toSkip returningNoMoreThan:(NSInteger)limit fromCollection:(NSString*)collection withError:(NSError**)error;
-(id)aggregateCollection:(NSString *) collection pipeline:(NSArray *)pipeline withError:(NSError**)error;
-(id)aggregateCollection:(NSString *) collection pipeline:(NSArray *)pipeline options:(NSDictionary *)options withError:(NSError**)error;

@property (copy) NSString* database;

@end
