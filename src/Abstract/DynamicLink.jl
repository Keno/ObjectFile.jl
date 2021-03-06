# Export DynamicLinks API
export DynamicLinks,
       getindex, endof, length, start, next, done, eltype,
       handle, header
       
# Export Dynamic Link API
export DynamicLink,
       DynamicLinks, handle, path

# Export RPath API
export RPath,
       handle, rpaths, canonical_rpaths, find_library
       

"""
    DynamicLinks

This type encapsulates the list of dynamic links within an object, holding a
collection of `DynamicLink` objects.  The list of available API operations is
given below, with methods that subclasses must implement marked in emphasis:

### Creation
  - *DynamicLinks()*

### Iteration
  - *getindex()*
  - *endof()*
  - length()
  - start()
  - next()
  - done()
  - eltype()

### Misc.
  - *handle()*
"""

abstract type DynamicLinks{H <: ObjectHandle} end

@mustimplement endof(dls::DynamicLinks)
start(dls::DynamicLinks) = 1
done(dls::DynamicLinks, idx) = idx > length(dls)
next(dls::DynamicLinks, idx) = (dls[idx], idx+1)
length(dls::DynamicLinks) = endof(dls)
eltype(::Type{D}) where {D <: DynamicLinks} = DynamicLink
@mustimplement getindex(dls::DynamicLinks, idx)

"""
    DynamicLink
  
This type encapsulates the linkage of one object file to another.  The list of
available API operations is given below, with methods that subclasses must
implement marked in emphasis:

### Creation:
  - *DynamicLink()*

### Accessors:
  - *DynamicLinks()*
  - *handle()*
  - *path()*
"""
abstract type DynamicLink{H <: ObjectHandle} end

@mustimplement path(dl::DynamicLink)


"""
    RPath

This type encapsulates the search path used by an object file when looking for
a shared library.  This class enables not only looking at the path, but
querying the path for matches for given library names.  The list of available
API operations is given below, with methods that subclasses must implement
marked in emphasis:

### Creation:
  - *RPath()*

### Utility
  - *handle()*

### RPath operations
  - *rpaths()*
  - canonical_rpaths()
  - find_library()
"""
abstract type RPath{H <: ObjectHandle} end

"""
    RPath(oh::ObjectHandle)

Construct an `RPath` object from the given `ObjectHandle`.
"""
@mustimplement RPath(oh::ObjectHandle)

"""
    handle(rpath::RPath)

Return the handle that this `RPath` object refers to.
"""
@mustimplement handle(rpath::RPath)

"""
    rpaths(rpath::RPath)

Return the list of paths that will be searched for shared libraries.
"""
@mustimplement rpaths(rpath::RPath)

endof(rpath::RPath) = endof(rpaths(rpath))
start(rpath::RPath) = 1
done(rpath::RPath, idx) = idx > length(rpath)
next(rpath::RPath, idx) = (rpath[idx], idx+1)
length(rpath::RPath) = endof(rpath)
eltype(::Type{D}) where {D <: RPath} = String
getindex(rpath::RPath, idx) = rpaths(rpath)[idx]


"""
    canonical_rpaths(rpath::RPath)

Return a canonicalized list of paths that will be searched.
"""
function canonical_rpaths(rpath::RPath)
    origin = dirname(path(handle(rpath)))
    paths = rpaths(rpath)
    for idx in 1:length(paths)
        # Substitute the path of the containing handle for `$ORIGIN` and
        # `@loader_path`.  Do the same for `@executable_path` even though
        # that's technically incorrect, because we don't have a good way to
        # track the web of dependencies right now.
        paths[idx] = replace(paths[idx], "\$ORIGIN", origin)
        paths[idx] = replace(paths[idx], "@loader_path", origin)
        paths[idx] = replace(paths[idx], "@executable_path", origin)
        paths[idx] = abspath(paths[idx])
    end
    return paths
end

"""
    find_library(rpath::RPath, soname::String)

Return the full path to a library, searching the given `RPath`, and then the
default library search paths.  This method takes the given `soname` and joins
it to the end of every path within the given `RPath`, returning the resultant
path if it exists, returning back the original `soname` if it doesn't.
"""
function find_library(rpath::RPath, soname::AbstractString)
    for path in canonical_rpaths(rpath)
        libpath = joinpath(path, soname)
        if isfile(libpath)
            return libpath
        end
    end
    return soname
end


### Printing
function show(io::IO, dl::DynamicLink{H}) where {H <: ObjectHandle}
    print(io, "$(format_string(H)) DynamicLink \"$(path(dl))\"")
end

show(io::IO, dls::DynamicLinks{H}) where {H <: ObjectHandle} = show_collection(io, dls, H)
show(io::IO, rp::RPath{H}) where {H <: ObjectHandle} = show_collection(io, rp, H)
