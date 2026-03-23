// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

contract ShakescoFeedRegistry {
    address private immutable i_caller;

    // asset => feed address
    // address(0) = native token (ETH/MATIC)
    mapping(address => address) private s_feeds;

    error FEEDREGISTRY__NOTCALLER();
    error FEEDREGISTRY__FEEDNOTSET();

    constructor(address caller) {
        i_caller = caller;
    }

    modifier onlyCaller() {
        if (msg.sender != i_caller) revert FEEDREGISTRY__NOTCALLER();
        _;
    }

    function setFeed(address asset, address feed) external onlyCaller {
        s_feeds[asset] = feed;
    }

    // batch update — update all feeds in one tx
    function setFeeds(
        address[] calldata assets,
        address[] calldata feeds
    ) external onlyCaller {
        require(assets.length == feeds.length, "Length mismatch");
        for (uint256 i = 0; i < assets.length; ) {
            s_feeds[assets[i]] = feeds[i];
            unchecked {
                ++i;
            }
        }
    }

    function getFeed(address asset) external view returns (address) {
        address feed = s_feeds[asset];
        if (feed == address(0)) revert FEEDREGISTRY__FEEDNOTSET();
        return feed;
    }
}
