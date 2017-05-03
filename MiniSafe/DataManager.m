//
//  DataManager.m
//  MiniSafe
//
//  Created by Jameson Weng on 2017-01-22.
//  Copyright © 2017 Jameson Weng. All rights reserved.
//

#import "DataManager.h"

@implementation DataManager

+ (id)sharedInstance {
    static DataManager *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[DataManager alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    if (!(self = [super init])) {
        NSLog(@"Failed to initalize object");
        return nil;
    }
    
    return self;
}

- (BOOL)openDatabase:(NSString *)password {
    NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *databasePath = [documentsDir stringByAppendingPathComponent:@"test.db"];
    
    sqlite3_stmt *preparedStmt;
    NSString *createTableCmd = @"CREATE TABLE IF NOT EXISTS data_table (title text PRIMARY_KEY, contents text);";
    
    // open a connection to the database
    if (sqlite3_open([databasePath UTF8String], &database) != SQLITE_OK) {
        NSLog(@"Failed to open database at %@", databasePath);
        return NO;
    }
    
    /*
    // register the key for encrypting/decrypting the database
    NSString *databaseKey = @"My secret key";
    if (sqlite3_key(database, [databaseKey UTF8String], [databaseKey length]) != SQLITE_OK) {
        NSLog(@"Failed to key the database");
        goto cleanupDatabase;
    }
    */
    
    // check if key was correct
    if (sqlite3_exec(database, "SELECT count (*) FROM sqlite_master;", NULL, NULL, NULL) != SQLITE_OK) {
        NSLog(@"sqlite3_exec failed - password was incorrect");
        goto cleanupDatabase;
    }
    
    // prepare the statement
    if (sqlite3_prepare_v2(database, [createTableCmd UTF8String], -1, &preparedStmt, NULL) != SQLITE_OK) {
        NSLog(@"Failed to prepare statement");
        goto cleanupDatabase;
    }
    
    // execute the statement
    if (sqlite3_step(preparedStmt) != SQLITE_DONE) {
        NSLog(@"Failed to create table to store user data");
        goto cleanupStmt;
    }
    
    sqlite3_finalize(preparedStmt); // free the prepared statement
    NSLog(@"Created table");
    
    return YES;

cleanupStmt:
    sqlite3_finalize(preparedStmt);
    
cleanupDatabase:
    sqlite3_close(database);
    
    return NO;
}

- (NSMutableArray *)getTitles {
    static NSString *getCmd = @"SELECT title FROM data_table;";
    
    NSMutableArray *titles = [[NSMutableArray alloc] init];
    sqlite3_stmt *preparedStmt;
    
    if (sqlite3_prepare_v2(database, [getCmd UTF8String], -1, &preparedStmt, NULL) != SQLITE_OK) {
        NSLog(@"Failed to prepare statement");
        return nil;
    }
    
    while (true) {
        int step_rv = sqlite3_step(preparedStmt);
        if (step_rv != SQLITE_OK && step_rv != SQLITE_DONE) {
            NSLog(@"failed to execute query statement");
            goto cleanupStmt;
        }
        
        [titles addObject:[NSString stringWithUTF8String:(const char*)sqlite3_column_text(preparedStmt, 0)]];
        
        if (step_rv == SQLITE_DONE) {
            break;
        }
    }

    return titles;
    
cleanupStmt:
    sqlite3_finalize(preparedStmt);
    return nil;
}

- (void)addTitle:(NSString *)title {
    static NSString *addCmd = @"INSERT INTO data_table (title, contents) VALUES (?1,'');";
    
    sqlite3_stmt *preparedStmt;
    
    // prepare the statement
    if (sqlite3_prepare_v2(database, [addCmd UTF8String], -1, &preparedStmt, NULL) != SQLITE_OK) {
        NSLog(@"Failed to prepare statement");
        return;
    }
    
    // bind the title to ?1
    if (sqlite3_bind_text(preparedStmt, 1, [title UTF8String], [title length], SQLITE_STATIC) != SQLITE_OK) {
        NSLog(@"Failed to bind title to sqlite statement");
        goto cleanupStmt;
    }
    
    // execute the statement
    if (sqlite3_step(preparedStmt) != SQLITE_DONE) {
        NSLog(@"Did not successfully add row to data table");
        goto cleanupStmt;
    }
    
cleanupStmt:
    sqlite3_finalize(preparedStmt);
}

- (void)removeTitle:(NSString *)title {
    
}

- (NSString *)getContentsForTitle:(NSString *)title {
    static NSString *query = @"SELECT contents FROM data_table WHERE title = ?1";
    
    sqlite3_stmt *preparedStmt;
    NSString *contents;
    
    // prepare the statement
    if (sqlite3_prepare_v2(database, [query UTF8String], -1, &preparedStmt, NULL) != SQLITE_OK) {
        NSLog(@"Failed to prepare statement");
        return nil;
    }
    
    // bind the title to ?1
    if (sqlite3_bind_text(preparedStmt, 1, [title UTF8String], [title length], SQLITE_STATIC) != SQLITE_OK) {
        NSLog(@"Failed to bind title to sqlite statement");
        goto cleanupStmt;
    }
    
    // execute the statement
    if (sqlite3_step(preparedStmt) != SQLITE_ROW) {
        NSLog(@"Did not find any rows matching title");
        goto cleanupStmt;
    }
    
    contents = [NSString stringWithUTF8String:(const char*)sqlite3_column_text(preparedStmt, 0)];
    
    sqlite3_finalize(preparedStmt);
    
    return contents;
    
cleanupStmt:
    sqlite3_finalize(preparedStmt);
    return nil;
}

- (void)setContents:(NSString *)contents forTitle:(NSString *)title {
    static NSString *insertCmd = @"UPDATE data_table SET contents = ?1 WHERE title = ?2;";
    
    sqlite3_stmt *preparedStmt;
    
    // prepare the statement
    if (sqlite3_prepare_v2(database, [insertCmd UTF8String], -1, &preparedStmt, NULL) != SQLITE_OK) {
        NSLog(@"Failed to prepare statement");
        return;
    }
    
    // bind contents to ?1
    if (sqlite3_bind_text(preparedStmt, 1, [contents UTF8String], [contents length], SQLITE_STATIC) != SQLITE_OK) {
        NSLog(@"Failed to bind contents to sqlite statement");
        goto cleanupStmt;
    }
    
    // bind title to ?2
    if (sqlite3_bind_text(preparedStmt, 2, [title UTF8String], [title length], SQLITE_STATIC) != SQLITE_OK) {
        NSLog(@"Failed to bind title to sqlite statement");
        goto cleanupStmt;
    }
  
    // execute statement
    if (sqlite3_step(preparedStmt) != SQLITE_DONE) {
        NSLog(@"Did not successfully insert into the table");
        goto cleanupStmt;
    }
    
cleanupStmt:
    sqlite3_finalize(preparedStmt);
}

- (void)cleanup {
    sqlite3_close(database);
}

@end