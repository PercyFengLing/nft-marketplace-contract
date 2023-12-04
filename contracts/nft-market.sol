// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Market is IERC721Receiver{
    
    IERC20 public erc20;
    IERC721 public erc721;

    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 
    0x150b7a02;

    struct Order {
        address seller;
        uint256 tokenId;
        uint256 price;
    }

    mapping(uint256 => Order) public orderOfId;
    Order[] public orders;
    mapping(uint256 => uint256) public idToOrderIndex;

    event Deal(address buyer, address seller, uint256 tokenId,
    uint256 price);
    event NewOrder(address seller, uint256 tokenId,
    uint256 price);
    event ChangePrice(
        address seller,
        uint256 tokenId,
        uint256 previousPrice,
        uint256 price
    );
    event CancleOrder(address seller, uint256 tokenId);

    constructor(IERC20 _erc20, IERC721 _erc721){
        require(address(_erc20) != address(0), "zero address");
        require(address(_erc721) != address(0), "zero address");
        erc20 = _erc20;
        erc721 = _erc721;
    }

    function buy(uint256 _tokenId) external {
        address seller = orderOfId[_tokenId].seller;
        address buyer = msg.sender;
        uint256 price = orderOfId[_tokenId].price;

        require(
            erc20.transferFrom(buyer, seller, price),
            "transfer not successful"
        );
        erc721.safeTransferFrom(address(this), buyer, _tokenId);

        removeListing(_tokenId);

        emit Deal(buyer, seller, _tokenId, price);
    }

    function cancelOrder(uint256 _tokenId) external {
        address seller = orderOfId[_tokenId].seller;
        require(msg.sender == seller, "not seller");

        erc721.safeTransferFrom(address(this), seller, _tokenId);

        removeListing(_tokenId);(_tokenId);

        emit CancleOrder(seller, _tokenId);
    }

    function changePrice(uint256 _tokenId, uint256 _price) external {
        address seller = orderOfId[_tokenId].seller;
        require(msg.sender == seller , "not seller");

        uint256 previousPrice = orderOfId[_tokenId].price;
        orderOfId[_tokenId].price = _price;

        Order storage order = orders[idToOrderIndex[_tokenId]];
        order.price = _price;

        emit ChangePrice(seller, _tokenId, previousPrice, _price);
    }

    function isListed(uint256 _tokenId) public view returns(bool) {
        return orderOfId[_tokenId].seller != address(0);
    }

    function onERC721Received(
        address _operator,
        address _seller,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4) {
        require(_operator == _seller, "seller must be operator");

        uint256 _price = toUint256(_data , 0);
        placeOrder(_seller, _tokenId, _price);

        return MAGIC_ON_ERC721_RECEIVED;
    }

    function removeListing(uint256 _tokenId) internal {
        // delete orderOfId[_tokenId];

        uint256 index = idToOrderIndex[_tokenId];
        uint256 lastIndex = orders.length - 1;
        if (index != lastIndex) {
            Order storage lastOrder= orders[lastIndex];
            orders[index] = lastOrder;
            idToOrderIndex[lastOrder.tokenId] = index;
        }
        orders.pop();
        delete orderOfId[_tokenId];
        delete idToOrderIndex[_tokenId];
    }

    function toUint256(
        bytes memory _bytes,
        uint256 _start
    ) public pure returns (uint256) {
        require(_start + 32 >= _start, "Market:toUint256_overflow");
        require(_bytes.length >= _start + 32, "Market:toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint :=mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function getOrderLength() external view returns (uint256) {
        return orders.length;
    }

    function getAllNFTs() external view returns (Order[] memory) {
        return orders;
    }

    function getMyNFTs() external view  returns (Order[] memory) {
        Order[] memory myOrders = new Order[](orders.length);
        uint256 count = 0;
        for (uint256 i = 0; i < orders.length; i++) {
            if(orders[i].seller == msg.sender) {
                myOrders[count] = orders[i];
                count++;
            }
        }

        // Order[] memory myOrdersTrimmed = new Order[](count);
        // for (uint256 i = 0; i< count; i++){
        //     myOrdersTrimmed[i] = myOrders[i];
        // }
        // return myOrdersTrimmed;
        return myOrders;
    }

    function placeOrder(
        address _seller,
        uint256 _tokenId,
        uint256 _price
    ) internal {
        require(_price > 0, "Market: Price must be greater than zero");

        orderOfId[_tokenId].seller = _seller;
        orderOfId[_tokenId].price = _price;
        orderOfId[_tokenId].tokenId = _tokenId;

        orders.push(orderOfId[_tokenId]);
        idToOrderIndex[_tokenId] = orders.length - 1;

        emit NewOrder(_seller, _tokenId, _price);
    }

}