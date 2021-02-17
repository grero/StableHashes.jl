# StableHashes
[![Build Status](https://travis-ci.com/grero/StableHashes.jl.svg?branch=master)](https://travis-ci.com/grero/StableHashes.jl)
[![Coverage Status](https://coveralls.io/repos/github/grero/StableHashes.jl/badge.svg?branch=master)](https://coveralls.io/github/grero/StableHashes.jl?branch=master)

An effort to preserve the julia hashing functionailty as it was under v.1.4.2.

To avoid conflict with the standard julia hashing machinery, `StableHashes` exports the function `shash`, which can be used as a drop-in replacement for the standard `hash` function, and will return hashes as though they were computed under julia v.1.4.2
