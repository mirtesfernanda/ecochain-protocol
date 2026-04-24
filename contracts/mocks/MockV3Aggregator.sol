// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockV3Aggregator
 * @notice Mock do Chainlink AggregatorV3Interface para uso em testes locais (Hardhat).
 * @dev Simula um price feed com decimais e resposta configuravel.
 *      Baseado no padrão oficial Chainlink para mocks de teste.
 */
contract MockV3Aggregator {
    uint8  public decimals;
    int256 public latestAnswer;
    uint256 public latestTimestamp;
    uint256 public latestRound;

    mapping(uint256 => int256)  private _answers;
    mapping(uint256 => uint256) private _timestamps;

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals        = _decimals;
        latestAnswer    = _initialAnswer;
        latestTimestamp = block.timestamp;
        latestRound     = 1;

        _answers[1]    = _initialAnswer;
        _timestamps[1] = block.timestamp;
    }

    /**
     * @notice Atualiza o preco simulado (util para testar diferentes cenarios de APR).
     */
    function updateAnswer(int256 _answer) external {
        latestRound++;
        latestAnswer    = _answer;
        latestTimestamp = block.timestamp;

        _answers[latestRound]    = _answer;
        _timestamps[latestRound] = block.timestamp;

        emit AnswerUpdated(_answer, latestRound, block.timestamp);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80  roundId,
            int256  answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80  answeredInRound
        )
    {
        roundId         = uint80(latestRound);
        answer          = latestAnswer;
        startedAt       = latestTimestamp;
        updatedAt       = latestTimestamp;
        answeredInRound = uint80(latestRound);
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80  roundId,
            int256  answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80  answeredInRound
        )
    {
        roundId         = _roundId;
        answer          = _answers[_roundId];
        startedAt       = _timestamps[_roundId];
        updatedAt       = _timestamps[_roundId];
        answeredInRound = _roundId;
    }
}
