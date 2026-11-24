-- Telephone Ring
-- "When this card is Normal Summoned: You can draw 1 card."
--
-- HOW TO REUSE THIS: almost every "When this card is Summoned: You can ..." effect
-- has this same shape. Copy this file, then change:
--   SetCode(EVENT_SUMMON_SUCCESS)  -> EVENT_SPSUMMON_SUCCESS (Special Summoned),
--                                     EVENT_FLIP_SUMMON_SUCCESS (Flip Summoned)
--   the target/operation functions -> what the effect actually does.
-- Similar real card to look at: Sangan, Hane-Hane, any "When this card is Normal Summoned" card.

-- GetID() gives this card's script table (s) and its ID number (id = 1900000000 here).
local s,id=GetID()

-- initial_effect runs once for every copy of the card when the duel starts.
-- It "registers" the card's effects with the rules engine.
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))            -- text shown to the player: "Prompt 1" in cards.txt
	e1:SetCategory(CATEGORY_DRAW)                    -- what kind of effect it is (used by negation, AI, etc.)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O) -- SINGLE = about this card itself; TRIGGER_O = optional trigger ("You can")
	e1:SetCode(EVENT_SUMMON_SUCCESS)                 -- WHEN it triggers: after this card is Normal Summoned
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)        -- the effect targets a player (the one who draws)
	e1:SetTarget(s.drtg)                             -- checks if it can be used + announces what it will do
	e1:SetOperation(s.drop)                          -- what happens when it resolves
	c:RegisterEffect(e1)
end

-- Target function. Called with chk==0 to ASK "can this effect be activated right now?"
-- (must return true/false), then called again to set things up when it is activated.
function s.drtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end -- tp = the player who controls this card
	Duel.SetTargetPlayer(tp)                              -- remember who draws...
	Duel.SetTargetParam(1)                                -- ...and how many
	Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)     -- tell the engine "this will draw 1" (for cards that respond to draws)
end

-- Operation function: the actual effect.
function s.drop(e,tp,eg,ep,ev,re,r,rp)
	local p,d=Duel.GetChainInfo(0,CHAININFO_TARGET_PLAYER,CHAININFO_TARGET_PARAM) -- read back who draws / how many
	Duel.Draw(p,d,REASON_EFFECT)
end
