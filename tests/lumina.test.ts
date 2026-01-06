
import { describe, expect, it } from "vitest";
import { Cl, ClarityType, ClarityValue, ResponseOkCV, cvToValue } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const address3 = accounts.get("wallet_3")!;

const unwrapOk = (response: ClarityValue): ClarityValue => {
  if (response.type !== ClarityType.ResponseOk) {
    throw new Error(`Expected ok, received ${response.type}`);
  }

  return (response as ResponseOkCV).value;
};

const uintValue = (value: ClarityValue) => BigInt(cvToValue(value));

describe("lumina core flows", () => {
  it("mints a token and records metadata", () => {
    const mint = simnet.callPublicFn(
      "lumina",
      "mint-lumina-art",
      [Cl.principal(address1), Cl.uint(500), Cl.stringAscii("ipfs://token-1")],
      address1
    );
    const tokenId = unwrapOk(mint.result);
    expect(mint.result).toBeOk(tokenId);

    const nextId = simnet.callReadOnlyFn("lumina", "get-lumina-next-token-id", [], address1);
    const nextTokenId = unwrapOk(nextId.result);
    expect(uintValue(nextTokenId)).toBe(uintValue(tokenId) + 1n);

    const uri = simnet.callReadOnlyFn("lumina", "get-lumina-token-uri", [tokenId], address1);
    expect(uri.result).toBeOk(Cl.some(Cl.stringAscii("ipfs://token-1")));

    const royalty = simnet.callReadOnlyFn("lumina", "get-lumina-royalty-info", [tokenId], address1);
    expect(royalty.result).toBeOk(
      Cl.some(Cl.tuple({ creator: Cl.principal(address1), percent: Cl.uint(500) }))
    );
  });

  it("lists and buys a token, transferring ownership and clearing the listing", () => {
    const mint = simnet.callPublicFn(
      "lumina",
      "mint-lumina-art",
      [Cl.principal(address1), Cl.uint(250), Cl.stringAscii("ipfs://token-2")],
      address1
    );
    const tokenId = unwrapOk(mint.result);

    const list = simnet.callPublicFn(
      "lumina",
      "list-lumina-art",
      [tokenId, Cl.uint(100_000)],
      address1
    );
    expect(list.result).toBeOk(Cl.bool(true));

    const listing = simnet.callReadOnlyFn("lumina", "get-lumina-listing", [tokenId], address1);
    expect(listing.result).toBeOk(
      Cl.some(Cl.tuple({ price: Cl.uint(100_000), listed: Cl.bool(true) }))
    );

    const buy = simnet.callPublicFn("lumina", "buy-lumina-art", [tokenId], address2);
    expect(buy.result).toBeOk(Cl.bool(true));

    const afterListing = simnet.callReadOnlyFn(
      "lumina",
      "get-lumina-listing",
      [tokenId],
      address1
    );
    expect(afterListing.result).toBeOk(Cl.none());

    const relistBySeller = simnet.callPublicFn(
      "lumina",
      "list-lumina-art",
      [tokenId, Cl.uint(120_000)],
      address1
    );
    expect(relistBySeller.result).toBeErr(Cl.uint(403));

    const relistByBuyer = simnet.callPublicFn(
      "lumina",
      "list-lumina-art",
      [tokenId, Cl.uint(120_000)],
      address2
    );
    expect(relistByBuyer.result).toBeOk(Cl.bool(true));
  });

  it("runs an auction from creation to settlement", () => {
    const mint = simnet.callPublicFn(
      "lumina",
      "mint-lumina-art",
      [Cl.principal(address1), Cl.uint(300), Cl.stringAscii("ipfs://token-3")],
      address1
    );
    const tokenId = unwrapOk(mint.result);

    const create = simnet.callPublicFn(
      "lumina",
      "create-lumina-auction",
      [tokenId, Cl.uint(1_000), Cl.uint(1_500), Cl.uint(144)],
      address1
    );
    expect(create.result).toBeOk(Cl.bool(true));

    const bid = simnet.callPublicFn(
      "lumina",
      "place-lumina-bid",
      [tokenId, Cl.uint(2_000)],
      address2
    );
    expect(bid.result).toBeOk(Cl.bool(true));

    simnet.mineEmptyBlocks(150);

    const settle = simnet.callPublicFn("lumina", "settle-lumina-auction", [tokenId], address3);
    expect(settle.result).toBeOk(Cl.bool(true));

    const transfer = simnet.callPublicFn(
      "lumina",
      "transfer-lumina-art",
      [tokenId, Cl.principal(address3)],
      address2
    );
    expect(transfer.result).toBeOk(Cl.bool(true));
  });

  it("rejects invalid batch mint input sizes", () => {
    const batch = simnet.callPublicFn(
      "lumina",
      "batch-mint-lumina-art",
      [
        Cl.list([Cl.principal(address1), Cl.principal(address2)]),
        Cl.list([Cl.uint(250)]),
        Cl.list([Cl.stringAscii("ipfs://token-4")]),
      ],
      address1
    );
    expect(batch.result).toBeErr(Cl.uint(417));
  });
});
