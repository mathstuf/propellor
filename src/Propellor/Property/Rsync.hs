module Propellor.Property.Rsync where

import Propellor.Base
import qualified Propellor.Property.Apt as Apt

type Src = FilePath
type Dest = FilePath

class RsyncParam p where
	toRsync :: p -> String

-- | A pattern that matches all files under a directory, but does not
-- match the directory itself.
filesUnder :: FilePath -> Pattern
filesUnder d = Pattern (d ++ "/*")

-- | Ensures that the Dest directory exists and has identical contents as
-- the Src directory.
syncDir :: Src -> Dest -> Property NoInfo
syncDir = syncDirFiltered []

data Filter 
	= Include Pattern
	| Exclude Pattern

instance RsyncParam Filter where
	toRsync (Include (Pattern p)) = "--include=" ++ p
	toRsync (Exclude (Pattern p)) = "--exclude=" ++ p

-- | A pattern to match against files that rsync is going to transfer.
--
-- See "INCLUDE/EXCLUDE PATTERN RULES" in the rsync(1) man page.
--
-- For example, Pattern "/foo/*" matches all files under the "foo"
-- directory, relative to the 'Src' that rsync is acting on.
newtype Pattern = Pattern String

-- | Like syncDir, but avoids copying anything that the filter list
-- excludes. Anything that's filtered out will be deleted from Dest.
--
-- Rsync checks each name to be transferred against its list of Filter
-- rules, and the first matching one is acted on. If no matching rule
-- is found, the file is processed.
syncDirFiltered :: [Filter] -> Src -> Dest -> Property NoInfo
syncDirFiltered filters src dest = rsync $
	[ "-av"
	-- Add trailing '/' to get rsync to sync the Dest directory,
	-- rather than a subdir inside it, which it will do without a
	-- trailing '/'.
	, addTrailingPathSeparator src
	, addTrailingPathSeparator dest
	, "--delete"
	, "--delete-excluded"
	, "--quiet"
	] ++ map toRsync filters

rsync :: [String] -> Property NoInfo
rsync ps = cmdProperty "rsync" ps
	`requires` Apt.installed ["rsync"]
