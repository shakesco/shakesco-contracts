import { newMockEvent } from "matchstick-as";
import { ethereum, Address, BigInt, Bytes } from "@graphprotocol/graph-ts";
import { Announcement } from "../generated/Contract/Contract";

export function createAnnouncementEvent(
  receiver: Address,
  amount: BigInt,
  tokenAddress: Address,
  businessTokenAddress: Address,
  pkx: Bytes,
  ciphertext: Bytes
): Announcement {
  let announcementEvent = changetype<Announcement>(newMockEvent());

  announcementEvent.parameters = new Array();

  announcementEvent.parameters.push(
    new ethereum.EventParam("receiver", ethereum.Value.fromAddress(receiver))
  );
  announcementEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  );
  announcementEvent.parameters.push(
    new ethereum.EventParam(
      "tokenAddress",
      ethereum.Value.fromAddress(tokenAddress)
    )
  );
  announcementEvent.parameters.push(
    new ethereum.EventParam(
      "businessTokenAddress",
      ethereum.Value.fromAddress(businessTokenAddress)
    )
  );
  announcementEvent.parameters.push(
    new ethereum.EventParam("pkx", ethereum.Value.fromFixedBytes(pkx))
  );
  announcementEvent.parameters.push(
    new ethereum.EventParam(
      "ciphertext",
      ethereum.Value.fromFixedBytes(ciphertext)
    )
  );

  return announcementEvent;
}
