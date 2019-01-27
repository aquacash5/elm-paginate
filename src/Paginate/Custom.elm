module Paginate.Custom exposing
    ( Paginated
    , init, map, changeItemsPerPage
    , goTo, next, prev, first, last
    , page, foldMap
    , pager, PagerOptions, elidedPager, currentPage, itemsPerPage, totalPages, isFirst, isLast
    )

{-| Pagination for custom collection types.

Only use this module if you want to paginate something other than a `List`. This might be useful if you desire an `Array` or `Dict` or even `LazyList` or `Stream` as your collection, however, you will need to provide a `length` and `slice` function to many of the functions here (see `Paginate` for an implementation example, and for full documentation). Most of the time `Paginate` is what you will want to use.


# The Paginated type

@docs Paginated


# Constructing and modifying

@docs init, map, changeItemsPerPage


# Changing pages

@docs goTo, next, prev, first, last


# Retrieving items

@docs page, foldMap


# Pager helpers

Functions to help build a "pager" and useful paging data

@docs pager, PagerOptions, elidedPager, currentPage, itemsPerPage, totalPages, isFirst, isLast

-}

import List.Extra
import Number.Bounded as Bounded exposing (Bounded)


{-| The `Paginated` type wraps your custom collection and holds all of the information necessary to track pagination. It does not modify your collection in any way (unless you call `Paginate.Custom.map`).
-}
type Paginated a
    = Paginated { itemsPerPage_ : Int, currentPage_ : Bounded Int, items : a }


{-| Create a new paginated collection. You must supply it with a function to get the length of your collection, as well as the desired number of items per page and your custom collection of items to be paginated. The current page is always initialized to 1. The minimum number of items per page is 1. The minimum number of total pages is 1 (even if you pass in an empty collection).
-}
init : (a -> Int) -> Int -> a -> Paginated a
init lengthFn itemsPerPage_ items =
    let
        max =
            if lengthFn items == 0 then
                1

            else
                ceiling <| toFloat (lengthFn items) / toFloat (Basics.max 1 itemsPerPage_)
    in
    Paginated
        { itemsPerPage_ = Basics.max 1 itemsPerPage_
        , currentPage_ = Bounded.between 1 max
        , items = items
        }


{-| Transform the collection inside the `Paginated` by providing a function to apply to the wrapped collection. You must supply a length function as the first argument, then the transformation function. This is how you map, filter, sort and update items. If this function changes the length of the collection, the pagination calculations will be updated accordingly. If the newly calculated number of pages is less than the current page, the current page will be set to the new last page.
-}
map : (a -> Int) -> (a -> a) -> Paginated a -> Paginated a
map lengthFn f (Paginated { currentPage_, itemsPerPage_, items }) =
    init lengthFn itemsPerPage_ (f items)
        |> goTo (Bounded.value currentPage_)


{-| Change the paging size. You must supply a length function as the first argument. The total number of pages will be updated accordingly, and the current page will remain unchanged if possible. If the newly calculated number of pages is less than the current page, the current page will be set to the new last page. The minimum paging size is 1 item per page.
-}
changeItemsPerPage : (a -> Int) -> Int -> Paginated a -> Paginated a
changeItemsPerPage lengthFn newItemsPerPage (Paginated { currentPage_, items }) =
    init lengthFn newItemsPerPage items
        |> goTo (Bounded.value currentPage_)


{-| Set the current page directly. If the specified page is "out of bounds" of the paginated collection, it will be set to the first or last page accordingly.
-}
goTo : Int -> Paginated a -> Paginated a
goTo i (Paginated p) =
    Paginated { p | currentPage_ = Bounded.set i p.currentPage_ }


{-| Go to the next page. Has no effect if you are already on the last page.
-}
next : Paginated a -> Paginated a
next (Paginated p) =
    Paginated { p | currentPage_ = Bounded.inc 1 p.currentPage_ }


{-| Go to the previous page. Has no effect if you are already on the first page.
-}
prev : Paginated a -> Paginated a
prev (Paginated p) =
    Paginated { p | currentPage_ = Bounded.dec 1 p.currentPage_ }


{-| Go to the first page.
-}
first : Paginated a -> Paginated a
first paginatedList =
    goTo 1 paginatedList


{-| Go to the last page.
-}
last : Paginated a -> Paginated a
last paginatedList =
    goTo (totalPages paginatedList) paginatedList


{-| Useful to conditionally show a "prev" button.
-}
isFirst : Paginated a -> Bool
isFirst (Paginated { currentPage_ }) =
    Bounded.value currentPage_ == 1


{-| Useful to conditionally show a "next" button.
-}
isLast : Paginated a -> Bool
isLast (Paginated { currentPage_ }) =
    Bounded.value currentPage_ == Bounded.maxBound currentPage_


{-| Get the current page of the `Paginated`.
-}
currentPage : Paginated a -> Int
currentPage (Paginated { currentPage_ }) =
    Bounded.value currentPage_


{-| Get the number of items per page.
-}
itemsPerPage : Paginated a -> Int
itemsPerPage (Paginated { itemsPerPage_ }) =
    itemsPerPage_


{-| Get the total number of pages.
-}
totalPages : Paginated a -> Int
totalPages (Paginated { currentPage_ }) =
    Bounded.maxBound currentPage_


{-| Remove the pagination context and run a function on the wrapped collection.
-}
foldMap : (a -> b) -> Paginated a -> b
foldMap f (Paginated { items }) =
    f items


{-| Get the "slice" of the wrapped collection for the current page. You must supply a "slice" function as the first argument, which will be with a "from" (inclusive) and a "to" (exclusive). Usually you would call this and pass the result on to your view function.
-}
page : (Int -> Int -> a -> a) -> Paginated a -> a
page sliceFn (Paginated { itemsPerPage_, currentPage_, items }) =
    let
        from =
            (Bounded.value currentPage_ - 1) * itemsPerPage_

        to =
            from + itemsPerPage_
    in
    sliceFn from to items


{-| Build a "pager" for your paginated collection. Usually you would use this to render the pager view. The supplied function is given the current page number being iterated over and whether that page is the current page.
-}
pager : (Int -> Bool -> b) -> Paginated a -> List b
pager f (Paginated { currentPage_ }) =
    List.range 1 (Bounded.maxBound currentPage_)
        |> List.map (\i -> f i (i == Bounded.value currentPage_))


{-| `PagerOptions` is used by the `elidedPager` function to configure window sizes and output format. See `elidedPager` for examples of its use. The available options are as follows:


### `innerWindow`

The number of page numbers to display on either side of the current page number. A negative number will be treated as `0`.


### `outerWindow`

The number of page numbers to display at the beginning and end of the page numbers. `0` means that the first and last pages will not be displayed. A negative number will be treated as `0`.


### `pageNumberView`

How to display the page numbers provided by the pager.


### `gapView`

How to represent the gaps between page windows (if there are any).

-}
type alias PagerOptions a =
    { innerWindow : Int, outerWindow : Int, pageNumberView : Int -> Bool -> a, gapView : a }


{-| Builds an "elided" pager, which displays a "gap" placeholder in-between the first and last page(s) and the current page, if there are enough pages to justify doing so. This is useful for large collections where the number of pages might be huge and you don't want to display all of the page numbers at once.

    renderPageNumberString pageNum isCurrentPage =
        if isCurrentPage then
            ">" ++ String.fromInt pageNum ++ "<"

        else
            String.fromInt pageNum

    pagerOptions =
        { innerWindow = 1
        , outerWindow = 1
        , pageNumberView = renderPageNumberString
        , gapView = "..."
        }

    paginatedList = fromList 2 (List.range 20) |> goTo 5

    elidedPager pagerOptions paginatedList
    --> [ "1", "...", "4", ">5<", "6", "...", "10" ]

    elidedPager { pagerOptions | innerWindow = 0, outerWindow = 0 } paginatedList
    --> [ ">5<" ]

-}
elidedPager : PagerOptions b -> Paginated a -> List b
elidedPager options (Paginated { currentPage_ }) =
    let
        currentPageNumber =
            Bounded.value currentPage_

        leftWindow =
            if options.outerWindow <= 0 then
                []

            else
                List.range
                    (Bounded.minBound currentPage_)
                    (Bounded.set (Bounded.minBound currentPage_ + (options.outerWindow - 1)) currentPage_ |> Bounded.value)

        rightWindow =
            if options.outerWindow <= 0 then
                []

            else
                List.range
                    (Bounded.set (Bounded.maxBound currentPage_ - (options.outerWindow - 1)) currentPage_ |> Bounded.value)
                    (Bounded.maxBound currentPage_)

        innerWindow =
            List.range
                (Basics.clamp (Bounded.minBound currentPage_) currentPageNumber (currentPageNumber - options.innerWindow))
                (Basics.clamp currentPageNumber (Bounded.maxBound currentPage_) (currentPageNumber + options.innerWindow))
    in
    leftWindow
        ++ innerWindow
        ++ rightWindow
        |> List.Extra.unique
        |> List.Extra.groupWhile (\prevPageNum nextPageNum -> nextPageNum - prevPageNum == 1)
        |> List.map (\( x, xs ) -> x :: xs)
        |> List.map (List.map (\i -> options.pageNumberView i (i == currentPageNumber)))
        |> List.Extra.intercalate [ options.gapView ]
