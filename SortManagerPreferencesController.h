/////////////////////////////////////////////////////////////////////////
// File:          $Name$
// Module:        Implements the Favorites preference panel
// Part of:       VitaminSEE
//
// Revision:      $Revision$
// Last edited:   $Date$
// Author:        $Author$
// Copyright:     (c) 2005 Elliot Glaysher
// Created:       2/22/05
//
/////////////////////////////////////////////////////////////////////////
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//  
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//  
// You should have received a copy of the GNU Lesser General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  
// USA
//
/////////////////////////////////////////////////////////////////////////


#import <Cocoa/Cocoa.h>

#import "SS_PreferencePaneProtocol.h"

@interface SortManagerPreferencesController : NSObject <SS_PreferencePaneProtocol> 
{
	IBOutlet NSView* prefView;
	IBOutlet NSArrayController* listOfDirectories;
}

-(IBAction)add:(id)sender;

-(IBAction)showHelp:(id)sender;

@end
